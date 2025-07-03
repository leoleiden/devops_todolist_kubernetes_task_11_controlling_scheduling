# Kubernetes ToDo App Deployment Instructions

## Опис проекту

Цей проект демонструє розгортання Django ToDo додатку в Kubernetes кластері з використанням kind. Проект включає MySQL базу даних та веб-додаток з налаштуванням Node Affinity, Pod Anti-Affinity та Taints.

## Передумови

- Docker встановлений та запущений
- kubectl встановлений та налаштований
- kind встановлений
- Git для клонування репозиторію

## Кроки розгортання

### 1. Підготовка середовища

```bash
# Клонуйте репозиторій
git clone <your-forked-repo>
cd <repo-name>

# Встановіть kind (якщо не встановлений)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### 2. Створення кластера

```bash
# Створіть кластер з конфігурації
kind create cluster --config=cluster.yml --name todoapp-cluster

# Перевірте стан кластера
kubectl cluster-info --context kind-todoapp-cluster
```

### 3. Інспекція та налаштування вузлів

```bash
# Перегляньте всі вузли та їх лейбли
kubectl get nodes --show-labels

# Перегляньте детальну інформацію про вузли
kubectl describe nodes

# Додайте taint для вузлів з лейблом app=mysql
kubectl get nodes -l app=mysql --no-headers | awk '{print $1}' | xargs -I {} kubectl taint nodes {} app=mysql:NoSchedule
```

### 4. Розгортання додатку

```bash
# Запустіть скрипт розгортання
chmod +x bootstrap.sh
./bootstrap.sh

# Альтернативно, виконайте команди вручну:
# MySQL компоненти
kubectl apply -f .infrastructure/mysql/ns.yml
kubectl apply -f .infrastructure/mysql/configMap.yml
kubectl apply -f .infrastructure/mysql/secret.yml
kubectl apply -f .infrastructure/mysql/service.yml
kubectl apply -f .infrastructure/mysql/statefulSet.yml

# TodoApp компоненти
kubectl apply -f .infrastructure/app/ns.yml
kubectl apply -f .infrastructure/app/pv.yml
kubectl apply -f .infrastructure/app/pvc.yml
kubectl apply -f .infrastructure/app/secret.yml
kubectl apply -f .infrastructure/app/configMap.yml
kubectl apply -f .infrastructure/app/clusterIp.yml
kubectl apply -f .infrastructure/app/nodeport.yml
kubectl apply -f .infrastructure/app/hpa.yml
kubectl apply -f .infrastructure/app/deployment.yml

# Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## Валідація змін

### 1. Перевірка StatefulSet MySQL

```bash
# Перевірте, що MySQL StatefulSet запущений
kubectl get statefulset -n mysql
kubectl get pods -n mysql

# Перевірте, що MySQL поди розгорнуті на правильних вузлах
kubectl get pods -n mysql -o wide

# Перевірте tolerations та affinity
kubectl describe pod -n mysql | grep -A 10 -E "(Tolerations|Affinity)"
```

### 2. Перевірка Deployment TodoApp

```bash
# Перевірте стан deployment
kubectl get deployment -n todoapp
kubectl get pods -n todoapp

# Перевірте HPA
kubectl get hpa -n todoapp

# Перевірте розподіл подів по вузлах
kubectl get pods -n todoapp -o wide

# Перевірте Node Affinity та Anti-Affinity
kubectl describe pod -n todoapp | grep -A 10 -E "(Tolerations|Affinity)"
```

### 3. Перевірка Node Affinity та Anti-Affinity

```bash
# Перевірте, що MySQL поди не розгорнуті на одному вузлі
kubectl get pods -n mysql -o wide

# Перевірте, що TodoApp поди не розгорнуті на одному вузлі
kubectl get pods -n todoapp -o wide

# Перевірте, що MySQL поди тільки на вузлах з лейблом app=mysql
kubectl get nodes -l app=mysql
kubectl get pods -n mysql -o wide
```

### 4. Перевірка Taints та Tolerations

```bash
# Перевірте taint'и на вузлах
kubectl describe nodes | grep -A 3 Taints

# Перевірте tolerations в MySQL подах
kubectl get pods -n mysql -o yaml | grep -A 5 tolerations
```

### 5. Функціональна перевірка додатку

```bash
# Перевірте сервіси
kubectl get svc -n todoapp
kubectl get svc -n mysql

# Перевірте доступність додатку через NodePort
kubectl get svc -n todoapp todoapp-nodeport
# Зверніться до додатку через http://localhost:<nodeport>

# Перевірте логи
kubectl logs -n todoapp -l app=todoapp
kubectl logs -n mysql -l app=mysql
```

## Очікувані результати

1. **MySQL StatefulSet**:
   - Запущений на вузлах з лейблом `app=mysql`
   - Має toleration для `app=mysql:NoSchedule`
   - Поди розгорнуті на різних вузлах (Pod Anti-Affinity)

2. **TodoApp Deployment**:
   - Має Node Affinity для вузлів з лейблом `app=todoapp`
   - Поди розгорнуті на різних вузлах (Pod Anti-Affinity)
   - HPA налаштований та працює

3. **Загальний стан**:
   - Всі поди в стані `Running`
   - Сервіси доступні
   - Додаток функціонує

## Очистка

```bash
# Видаліть кластер
kind delete cluster --name todoapp-cluster

# Або видаліть всі ресурси
kubectl delete namespace mysql todoapp
```

## Додаткові команди для діагностики

```bash
# Перевірте стан всіх подів
kubectl get pods --all-namespaces

# Перевірте події в кластері
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Перевірте використання ресурсів
kubectl top nodes
kubectl top pods --all-namespaces
```

## Примітки

- Переконайтеся, що всі образи доступні та можуть бути завантажені
- Якщо поди не запускаються, перевірте логи та події
- Для production використання додайте додаткові налаштування безпеки
- Розгляньте використання Helm для спрощення управління