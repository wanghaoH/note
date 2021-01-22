#!/bin/env bash

LANG=C

project_list="
backend/deploy-docs
backend/baobao-deploy
backend/baobao-parent
backend/baobao-backend-web
backend/baobao-backend
backend/baobao-admin-backend
module/baobao-module-fight
module/baobao-module-rank
module/baobao-module-mike
module/baobao-module-qq
module/baobao-module-wechat
module/baobao-module-warehouse
module/baobao-module-user
module/baobao-module-tours
module/baobao-module-staff
module/baobao-module-sdk
module/baobao-module-scheduler
module/baobao-module-replenish
module/baobao-module-relations
module/baobao-module-pay
module/baobao-module-order
module/baobao-module-moego
module/baobao-module-market
module/baobao-module-incident
module/baobao-module-activity
"

for project in ${project_list}
do
    project_dir=`echo ${project}|awk -F '/' '{print $NF}'`
    if [ ! -d ${project_dir} ]
    then
        git clone git@10.7.1.115:baobao/${project}.git
    else
        cd ${project_dir} && git config pull.rebase false ; git pull && cd -
    fi
done
