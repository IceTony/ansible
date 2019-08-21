## Установка Ansible на Ubuntu
```
sudo apt update
sudo apt install software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```
## Пример запуска плейбуков
```ansible-playbook -i inventory install_nginx.yml```

