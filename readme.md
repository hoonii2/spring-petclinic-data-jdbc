# 프로젝트

[spring-petclinic-data-jdbc](https://github.com/spring-petclinic/spring-petclinic-data-jdbc) 를 대상으로 devops 목적을 달성합니다.


## 아키텍처
1. 배포 서버 URL
    - http://www.khleeproject.kro.kr
    <br>

2. 전체 아키텍처
    - GCP Google Kubernetes Engine 을 활용했습니다.
![image](https://github.com/hoonii2/spring-petclinic-data-jdbc/assets/17640541/1a19f22c-143a-4313-affc-bdceaa809a67)
<br>

3. CI/CD Flow
![image](https://github.com/hoonii2/spring-petclinic-data-jdbc/assets/17640541/7ac0daf1-cc1b-4f94-9ed3-fd9f30b2d5a5)
<br>


## 요구사항
### 1. gradle 사용 및 어플리케이션, 도커이미지 빌드
1. maven to gradle 프로젝트 빌드 방식 변경
    - 구성 정보 : [build.gradle](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/build.gradle)
    - gradle 빌드 시 필요한 파일 추가 후  ".\gradlew init" 를 통한 gradle 프로젝트로 변경
    - build.gradle 내 의존성 및 Java 버전 변경 후 gradle build 동작 확인  
    <br>
2. Docker 이미지 빌드를 위한 Dockerfile 구성
    - 구성 정보 : [Dockerfile](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/Dockerfile)
    <br>

### 2. 어플리케이션의 log 는 host의 '/logs' 적재
1. 저장소 관련 사항
    1. GKE Node 의 filesystem read-only 이슈
        1. host 의 '/logs' directory 는 hostpath Persistent Volume 으로 구성
            - 구성 정보 : [Persistent Volume](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/storage/hostpath/petclinic-app-pv.yaml)
            <br>
        2. petclinic-app 에서 PV 사용을 위해 Persistent Volume Claim 구성
            - 구성 정보 : [Persistent Volume Claim](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/storage/hostpath/petclinic-app-pvc.yaml)
            <br>
        3. read-only 이슈 정보 확인
            ``` shell
            #!Shell ( logging info )

            Events:
              Type     Reason       Age                From               Message
              ----     ------       ----               ----               -------  
              Normal   Scheduled    86s                default-scheduler  Successfully assigned default/petclinic-app-rollout-bluegreen-6f9d8b966-4wqvm to gke-codementor-cluster-default-pool-7815dfdb-l1vd  
              Warning  FailedMount  22s (x8 over 85s)  kubelet            MountVolume.SetUp failed for volume "petclinic-app-pv" : mkdir /logs: read-only file system
            ```
            <br>

    2. GCP hostPath readwritemany [미지원](https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes?hl=ko#access_modes)
    <br>

    3. 대안 : GCP Persistent Disk NFS 사용
        1. GCP Persistent Disk 사용하는 NFS 배포 후 NFS 에서 제공하는 저장소를 readwritemany 로 PV, PVC 연결
            - 구성 정보 : [NFS Server](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/storage/gcp-nfs/nfs.yaml), [NFS PV](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/storage/gcp-nfs/nfs-pv.yaml), [NFS PVC](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/storage/gcp-nfs/nfs-pvc.yaml)
            <br>
        2. 위 PVC 를 활용하여 여러 Pod 에서 사용
            - 구성 정보 : [petclinic-app](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-rollouts.yaml#L44-L50)
            <br>

2. 로깅 설정 관련 사항
    1. Spring Boot container 실행 시 마운트한 NFS Directory 내 표준출력, 에러출력 로그 파일 저장
        - 구성 정보 : [Docker file](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/Dockerfile#L6)
        - 로그 파일 저장 시 Scale-out 을 고려하여 "년월일_Pod이름" 형식 사용
            - 예시, 20240122_petclinic-app-rollout-bluegreen-7454884f5b-5qxqj.log
            <br>

### 3. 정상 동작 여부 반환 api 구현, 10초 주기로 체크
1. 정상 동작 여부 반환 api 구현
    - 구성 정보 : [Rest Controller](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/src/main/java/org/springframework/samples/petclinic/health/HealthController.java#L6-L12)
    - /api/health GET 요청 시 "UP" 반환하는 API 구현
    <br>
2. 10초 주기로 체크
    - 구성 정보 : [petclinic-app livenessProbe](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-rollouts.yaml#L38-L43)
    - GET 요청 후 200~300 정상 응답 체크하는 livenessProbe 사용
    <br>

### 4. 종료 시 30초 이내 프로세스 미종료 시 SIGKILL 강제 종료
1. 30초 대기 후 강제 종료 구현
    - 구성 정보 : [petclinic-app graceful termination](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-rollouts.yaml#L51)
    - Pod 종료 요청 SIGTERM 이후 30초간 대기한 뒤 미종료시 SIGKILL 강제 종료
    <br>

### 5. 배포 시 scale-in, out 시 트래픽 유실 금지
1. Argo CD, Argo rollout 사용하여 blue/green 배포 구성
    - 구성 정보 : [petclinic-app rollout](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-rollouts.yaml)
    - Argo CD 구성 정보 확인 : https://argocd.khleeproject.kro.kr admin / hTQHW3Kp8kKQu9Gi
        - 필요한 replica 수 만큼 새로운 green replicaSet 정상 배포 이후 교체되기에 유실 트래픽은 없습니다. ( replica: 1 사황 포함 )
        <br>

### 6. 어플리케이션 프로세스 uid:999 실행
1. securityContext 활용하여 계정 설정
    - 구성 정보 : [petclinic-app securityContext](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-rollouts.yaml#L16-L19)
    <br>
2. initContainer 를 활용하여 로깅 볼륨 소유자 설정
    - 구성 정보 : [petclinic-app initContainer](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-rollouts.yaml#L21-L31)
    - fsGroup 으로 소유그룹 변경했으나 마운트 볼륨이 mod 755 로 소유자만 write 가능하여 initContainer 를 활용하여 소유자 변경
    1. Mount volume directory 소유자 확인
        ``` shell
        /logs # ls -al
        total 108
        drwxr-xr-x    3 999      ping          4096 Jan 22 07:59 .
        drwxr-xr-x    1 root     root          4096 Jan 22 07:59 ..
        -rw-r--r--    1 999      ping          7474 Jan 21 21:03 20240121_petclinic-app-rollout-bluegreen-569854644c-kgq4j.log
        -rw-r--r--    1 999      ping             0 Jan 21 20:34 20240121_petclinic-app-rollout-bluegreen-569854644c-kgq4j_error.log
        -rw-r--r--    1 999      ping         12614 Jan 22 05:43 20240121_petclinic-app-rollout-bluegreen-79f5ddbc6-8stdc.log
        -rw-r--r--    1 999      ping             0 Jan 21 21:12 20240121_petclinic-app-rollout-bluegreen-79f5ddbc6-8stdc_error.log
        -rw-r--r--    1 999      ping          8552 Jan 22 05:43 20240121_petclinic-app-rollout-bluegreen-79f5ddbc6-gskdq.log
        ```
        <br>

### 7. DB 재 실행 시 변경된 데이터 유실 금지
1. StatefulSet 을 활용하여 DB 구성 및 primary secondary replication 환경 구성
    - 구성 정보 : [mysql statefulset](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/mysql/mysql-statefulset.yaml)
    - 참고 자료 : [k8s doc](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/)
    - DB 데이터, 상태 유지를 위해 StatefulSet 및 MySQL Replication 사용
    <br>


### 8. App - DB 는 Cluster Domain 으로 통신
1. Spring boot 에서 DB 접근 시 headless Service 로 Cluster Domain 사용 ( Pod.svc.namespace )
    - 구성 정보 : [application.yaml](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/src/main/resources/application.properties#L2)
    - 비밀번호는 공개하면 안되지만 과제 특성 상 개시
    <br>

### 9. ingress-controller 를 통해 어플리케이션 접속
1. Petclinic-app ClusterIP type Service 사용
    - 구성 정보 : [petclinic-app-svc.yaml](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-service.yaml#L1-L11)
    - 외부 공개는 Ingress-Cluster 를 사용하므로 ClusterIP type 사용
    <br>
2. Ingress 구성하여 Ingress Controller 연결
    - 구성 정보 : [petclinic-app-ingress](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/manifests/petclinic-app/petclinic-app-ingress.yaml)
    - Ingress 를 사용하여 위 Service 연결
    - GKE Ingress "gcp" annotation 사용 시 gke controller 에서 ingress controller 자동 구성
        - [관련 사항](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress?hl=ko#controller_summary)
        <br>

### 10. default namespace 사용
1. default namespace 정보
    ``` shell
    $ kubectl get pod,rollout,svc,ingress
    NAME                                                  READY   STATUS    RESTARTS   AGE
    pod/dbc1-0                                            1/1     Running   0          25h
    pod/dbc1-1                                            1/1     Running   0          25h
    pod/nfs-server-6b4f95d5d4-hngm6                       1/1     Running   0          20h
    pod/petclinic-app-rollout-bluegreen-fd4fd48f8-4z4lj   1/1     Running   0          7h30m
    pod/petclinic-app-rollout-bluegreen-fd4fd48f8-x6d5v   1/1     Running   0          7h30m
    
    NAME                                                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    rollout.argoproj.io/petclinic-app-rollout-bluegreen   2         2         2            2           20h
    
    NAME                                              TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
    service/mysql                                     ClusterIP      None           <none>        3306/TCP                     25h
    service/mysql-read                                ClusterIP      10.16.9.66     <none>        3306/TCP                     25h
    service/nfs-server                                ClusterIP      10.16.13.145   <none>        2049/TCP,20048/TCP,111/TCP   20h
    service/petclinic-app-rollout-bluegreen-active    ClusterIP      10.16.1.134    <none>        80/TCP                       20h
    service/petclinic-app-rollout-bluegreen-preview   ClusterIP      10.16.1.91     <none>        80/TCP                       20h
    
    NAME                                              CLASS    HOSTS   ADDRESS         PORTS   AGE
    ingress.networking.k8s.io/petclinic-app-ingress   <none>   *       34.117.76.120   80      11h
    ```
    <br>


## 추가 구성
### 1. Github Action CI
1. Github Action 을 활용하여 CI 구성
    - 구성 정보 : [github action workflow](https://github.com/hoonii2/spring-petclinic-data-jdbc/blob/master/.github/workflows/main.yml)
    1. Gradle Build 및 Docker 이미지를 생성하고 Docker Hub 에 이미지를 Push 
        - 이미지 버전은 timestamp 활용 ( Image : lkh66913:${timestamp}})
        <br>
    2. 새롭게 Push 된 timestamp 버전은 rollout.yaml 내용 업데이트
    <br>

2. Argo CD 구성
    - 구성 정보 : 항목 5 를 통해 Argo CD 접근 가능
    1. rollout.yaml 의 버전 내용 업데이트 시 자동 blue/green 배포 수행
