#! /bin/bash
if [[ $(whoami) != "root" ]]; then
    echo "This script must be run as root."
    exit 1
fi
DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ ${DISTRO} != '"Ubuntu"' && ${DISTRO} != '"Debian"' ]]; then
    echo "This script is for ubuntu and debian only."
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
    curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - >>dashactyl-script.log
    apt-get install nodejs yarn -y >>dashactyl-script.log
else
    echo "NodeJS is already installed, not installing it."
fi
echo "Installing dashactyl in /var/www/dashactyl"
mkdir /var/www/dashactyl
cd /var/www/dashactyl || exit 1
git clone https://github.com/real2two/dashactyl ./
npm install --production
npm i -g json >>dashactyl-script.log
echo "Do you want to do config using this script? [Y/n] "
read -r configOPT
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
    echo "What domain is your Pterodactyl Panel hosted on? "
    read -r pterodactylDOMAIN
    sed -i "s/pterodactyl panel domain/$pterodactylDOMAIN/" settings.json
    echo "Please enter a pterodactyl panel admin/application api key with all permissions. "
    read -r pterodactylAPIKEY
    sed -i "s/pterodactyl panel admin api key with all read and writes/$pterodactylAPIKEY/" settings.json
    echo "Enable Dashactyl API? [y/N] "
    read -r dashactylAPIQUESTION
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
    echo "Discord Bot Token for Dashactyl? "
    read -r discordBotTOKEN
    json -I -f settings.json -e "this.api.client.bot.token='$discordBotTOKEN'"
    echo "Do you want to enable Join Guild? [Y/n] "
    read -r joinGUILDOPT
    case "$joinGUILDOPT" in
    y | Yes | Y)
        json -I -f settings.json -e "this.api.client.bot.joinguild.enabled=true"
        echo "Guild ID you want to autojoin? " 
        read -r guildIDAJ
        json -I -f settings.json -e 'this.api.client.bot.joinguild.guildid=["'$guildIDAJ'"]'
        ;;
    n | No | N)
        echo ""
        ;;
    esac
    echo "Enable discord webhook logging? [Y/n] "
    read -r discordloggingOPT
    case "$discordloggingOPT" in
    y | Yes | Y)
        echo "Enabling Discord webhook logging..."
        echo "Discord Webhook URL? [Y/n] "
        read -r discordwebhookURL
        json -I -f settings.json -e "this.api.client.webhook.webhook_url='$discordwebhookURL'"
        json -I -f settings.json -e "this.api.client.webhook.auditlogs.enabled=true"
        ;;
    n | No | N)
        echo ""
        ;;
    esac
    echo "You must setup locations, packages and store yourself."
    json -I -f settings.json -e "this.api.client.passwordgenerator.signup=true"
    json -I -f settings.json -e "this.api.client.passwordgenerator.length=16"
    read -r discordappID
    json -I -f settings.json -e "this.api.client.oauth2.id='$discordappID'"
    echo "Discord oauth2 application Secret? "
    read -r discordappSECRET
    json -I -f settings.json -e "this.api.client.oauth2.id='$discordappSECRET'"
    echo "Discord oauth2 application url without the /callback? "
    read -r discordappURL
    json -I -f settings.json -e "this.api.client.oauth2.id='$discordappURL'"
    json -I -f settings.json -e "this.api.client.ratelimits.requests=1"
    json -I -f settings.json -e "this.api.client.ratelimits['per second']=1"
    echo "Do you want to use arc.io? [Y/n] "
    read -r arcioOPT
    case "$arcioOPT" in
    y | Yes | Y)
        echo "Enabling arc.io"
        echo "What is your arc.io widget ID? "
        read -r arcwidgetID
        json -I -f settings.json -e "this.api.arcio.enabled=true"
        json -I -f settings.json -e "this.api.arcio.widgetid='$arcwidgetID'"
        echo "Do you want to enable arc.io AFK page? [Y/n] "
        read -r afkpageOPT
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
echo "Setup NGINX Reverse Proxy? [Y/n] "
read -r nginxreverseproxyOPT
case "$nginxreverseproxyOPT" in
y | Yes | Y)
    echo "Nginx reverse proxy"
    echo "Installing Dependencies"
    apt-get install -y certbot nginx >>dashactyl-script.log
    systemctl start nginx
    echo "What domain do you want to install dashactyl on? (Must not include http:// or https://) "
    read -r nginxDOMAIN
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
npm i -g pm2 >>dashactyl-script.log
echo "Done! Dashactyl is now installed."
cd /var/www/dashactyl || exit 1
echo "Run pm2 start index.js to start dashactyl."
