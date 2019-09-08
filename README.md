## Установка Ansible на Ubuntu
```
sudo apt update
sudo apt install software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```
## Пример запуска плейбуков
```ansible-playbook -i inventory install_nginx.yml```
## Установка ролей через Ansible Galaxy
1. Добавить в файл ```plays/roles/requirements.yml``` необходимые роли:
```
- src: geerlingguy.mysql
- src: geerlingguy.phpmyadmin
```
2. Выполнить загрузку ролей:
```
ansible-galaxy install -r requirements.yml --roles-path plays/roles
```
