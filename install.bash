#! /bin/bash
if [[ $(whoami) != "root" ]]; then
    echo "This script must be run as root."
    exit 1
fi
DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ ${DISTRO} != '"Ubuntu"' ]]; then
    echo "This script is for ubuntu only."
    exit 1
fi
mkdir -p /var/www/dashactyl
echo "Installing Dependencies..."
apt-get update >>dashactyl-script.log
echo "Installing Dependencies Log" >>dashactyl-script.log
apt-get install -y nano git curl software-properties-common jq >>dashactyl-script.log
echo "Checking if nodejs is installed, else installing it."
if [[ -z $(command -v node) ]]; then
    echo "NodeJS is not installed, Installing..."
    curl -sL https://deb.nodesource.com/setup_12.x | bash >>dashactyl-script.log
    apt-get update >>dashactyl-script.log
    apt-get install nodejs npm -y >>dashactyl-script.log
else
    echo "NodeJS is already installed, not installing it."
fi
echo "Installing dashactyl in /var/www/dashactyl"
mkdir /var/www/dashactyl
cd /var/www/dashactyl || exit 1
git clone https://github.com/real2two/dashactyl ./
npm install --production
npm i -g json >>dashactyl-script.log
read -r -p "Do you want to do config using this script? [Y/n] " configOPT
case "$configOPT" in
y | Yes | Y)
    echo "Doing config"
    echo "Port 3690 will be used to run dashactyl."
    sed -i "s/80/3690/" settings.json
    secretKEY=$(
        tr -dc A-Za-z0-9 </dev/urandom | head -c 69
        echo ''
    )
    sed -i "s/change this website session secret password, make sure to change this for your website's security/$secretKEY/" settings.json
    read -r -p "What domain is your Pterodactyl Panel hosted on? " pterodactylDOMAIN
    sed -i "s/pterodactyl panel domain/$pterodactylDOMAIN/" settings.json
    read -r -p "Please enter a pterodactyl panel admin/application api key with all permissions. " pterodactylAPIKEY
    sed -i "s/pterodactyl panel admin api key with all read and writes/$pterodactylAPIKEY/" settings.json
    read -r -p "Enable Dashactyl API? [y/N] " dashactylAPIQUESTION
    case "$dashactylAPIQUESTION" in
    y | Yes | Y)
        echo "Enabling Dashactyl API"
        json -I -f settings.json -e "this.api.client.api.enabled=true"
        apiCODE=$(
            tr -dc A-Za-z0-9 </dev/urandom | head -c 69
            echo ''
        )
        echo "Your API token is $apiCODE"
        json -I -f settings.json -e "this.api.client.api.code='$apiCODE'"
        ;;
    n | No | N)
        echo "Disabling Dashactyl API"
        json -I -f settings.json -e "this.api.client.api.enabled=false"
        ;;
    esac
    read -r -p "Discord Bot Token for Dashactyl? " discordBotTOKEN
    json -I -f settings.json -e "this.api.client.bot.token='$discordBotTOKEN'"
    read -r -p "Do you want to enable Join Guild? [Y/n] " joinGUILDOPT
    case "$joinGUILDOPT" in
    y | Yes | Y)
        json -I -f settings.json -e "this.api.client.bot.joinguild.enabled=true"
        read -r -p "Guild ID you want to autojoin? " guildIDAJ
        json -I -f settings.json -e 'this.api.client.bot.joinguild.guildid=["'$guildIDAJ'"]'
        ;;
    n | No | N)
        echo ""
        ;;
    esac
    read -r -p "Enable discord webhook logging? [Y/n] " discordloggingOPT
    case "$discordloggingOPT" in
    y | Yes | Y)
        echo "Enabling Discord webhook logging..."
        read -r -p "Discord Webhook URL? [Y/n] " discordwebhookURL
        json -I -f settings.json -e "this.api.client.webhook.webhook_url='$discordwebhookURL'"
        json -I -f settings.json -e "this.api.client.webhook.auditlogs.enabled=true"
        json -I -f settings.json -e "this.api.client.ratelimits['per second']=1"
        ;;
    n | No | N)
        echo ""
        ;;
    esac
    echo "You must setup locations, packages and store yourself."
    json -I -f settings.json -e "this.api.client.passwordgenerator.signup=true"
    json -I -f settings.json -e "this.api.client.passwordgenerator.length=16"
    read -r -p "Discord oauth2 application ID? " discordappID
    json -I -f settings.json -e "this.api.client.oauth2.id='$discordappID'"
    read -r -p "Discord oauth2 application Secret? " discordappSECRET
    json -I -f settings.json -e "this.api.client.oauth2.id='$discordappSECRET'"
    read -r -p "Discord oauth2 application url without the /callback? " discordappURL
    json -I -f settings.json -e "this.api.client.oauth2.id='$discordappURL'"
    json -I -f settings.json -e "this.api.client.ratelimits.requests=1"
    json -I -f settings.json -e "this.api.client.ratelimits.per second=1"
    read -r -p "Do you want to use arc.io? [Y/n] " arcioOPT
        case "$arcioOPT" in
        y | Yes | Y)
            echo "Enabling arc.io"
            read -r -p "What is your arc.io widget ID? " arcwidgetID
            json -I -f settings.json -e "this.api.arcio.enabled=true"
            json -I -f settings.json -e "this.api.arcio.widgetid='$arcwidgetID'"
            read -r -p "Do you want to enable arc.io AFK page? [Y/n] " afkpageOPT
            case "$afkpageOPT" in
            y | Yes | Y)
                echo "Enabling AFK Page"
                json -I -f settings.json -e "this.api.arcio['afk page'].enabled=true"
                echo "Users will earn 1 coin per minute, feel free to edit it in settings.json"
                ;;
            n | No | N)
                echo ""
                ;;
            esac
            ;;
        n | No | N)
            echo ""
            ;;
        esac
    ;;
n | No | N)
    echo "Not doing config"
    ;;
esac
read -r -p "Setup NGINX Reverse Proxy? [Y/n] " nginxreverseproxyOPT
case "$nginxreverseproxyOPT" in
y | Yes | Y)
    echo "Nginx reverse proxy"
    echo "Installing Dependencies"
    apt-get install -y certbot nginx >> dashactyl-script.log
    systemctl start nginx
    read -r -p "What domain do you want to install dashactyl on? (Must not include http:// or https://) " nginxDOMAIN
    certboat=$(certbot certonly --nginx -d "$nginxDOMAIN")
    if [[ "$certboat" == *"Congratulations! Your certificate and chain"* ]]; then
        echo "SSL was done successfully."
    else
        echo "SSL failed, here's the error message: "
        echo "$certboat"
    fi
    cd /etc/nginx/conf.d || exit 1
    rm dashactyl.conf
    wget https://raw.githubusercontent.com/chirag350/dashactyl-install-script/nginx-conf/dashactyl.conf
    sed -i "s/hereIsTheDomain/$nginxDOMAIN/g" dashactyl.conf
    sed -i "s/HereIsThePort/3690/g" dashactyl.conf
    echo "Restarting NGINX to apply final changes."
    systemctl restart nginx
    ;;
n | No | N)
    echo "Not doing reverse proxy."
    ;;
esac
npm i -g pm2 >> dashactyl-script.log
echo "Done! Dashactyl is now installed."
cd /var/www/dashactyl || exit 1
echo "Run pm2 start index.js to start dashactyl."