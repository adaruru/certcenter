function devCertcenter {
    cd D:\Users\AmandaChou\git\itsower\certcenter
    backToDefault
    docker build -t certcenter:test .
    docker-compose up -d
}

function TestCertCenter {
    $url= "http://localhost:9250"
    Write-Host "now test $url"
    curl $url/register
}

function TestIssueCertCenter {
    curl -X POST "http://localhost:9250/cert?domain=*.itsower.com.tw"
}

function TestDownCertCenter {
    # curl -OJ "http://localhost:9250/cert?domain=*.itsower.com.tw"
}
 
# 查詢到期日：
# curl "http://localhost:9250/expire?domain=*.itsower.com.tw"
# 強制更新：
# curl -X POST "http://localhost:9250/renew?domain=*.itsower.com.tw"



function Test63RenewCertCenter {
    Write-Host "Test63RenewCertCenter"
    createAndUse63
    docker exec -it its-certcenter /bin/bash
}

function LocalTestRenewCertCenter {
    Write-Host "LocalTestRenewCertCenter"
    createAndUse63
    docker exec -it its-certcenter /bin/bash
    # 看 cron 任務有沒有跑起來
    # crontab -l
    # 看 cron 進程有沒有跑起來
    # which cron
    # which crond
    # ps -ef | grep cron
    # if pid=$(cat /var/run/crond.pid 2>/dev/null) && [ "$(cat /proc/$pid/comm 2>/dev/null)" = "cron" ]; then echo "cron running (pid=$pid)"; else echo "cron not running"; fi

    # cat /var/run/crond.pid && cat /proc/423/comm
    # cat /var/log/acme-cron.log
}

