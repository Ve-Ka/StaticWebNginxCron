FROM nginx:alpine
ARG giturl
ARG webrootpath="/usr/share/nginx/html"
ARG fqdn
ARG filename
RUN apk add --no-cache git
RUN git clone $giturl $webrootpath/$filename
RUN tee /etc/nginx/conf.d/default.conf > /dev/null <<EOF
server {
    listen 80 default_server;
    root $webrootpath;
    index index.html index.htm;
    server_name _;

    location ~ ^/$ {
        return 301 https://$fqdn/$filename/index.html;
        try_files \$uri \$uri/ =404;
    }
}
EOF

RUN tee /home/gitPull.sh > /dev/null <<EOF
cronLog='/home/cron.log'
echo \`date +'%Y-%m-%d %H:%M:%S'\`" ::: Git Pull START" >> \$cronLog
git -C $webrootpath/$filename fetch --quiet
git -C $webrootpath/$filename remote prune origin
git -C $webrootpath/$filename checkout -f --quiet
git -C $webrootpath/$filename pull -f --quiet
success=\$?
if [ \$success -eq 0 ]; then
    echo \`date +'%Y-%m-%d %H:%M:%S'\`" ::: Git Pull END" >> \$cronLog
    nginx -s reload
    echo \`date +'%Y-%m-%d %H:%M:%S'\`" ::: Nginx Reloaded" >> \$cronLog
else
    echo \`date +'%Y-%m-%d %H:%M:%S'\`" ::: Git Pull FAILED" >> \$cronLog
fi
EOF
# Bug with tee command above adding carriage-return ^M character at end of each line
RUN sed -i 's/\r$//' /home/gitPull.sh
RUN chmod +x /home/gitPull.sh
RUN echo '* */6 * * * /home/gitPull.sh >/dev/null 2>&1' >> /etc/crontabs/root
CMD crond && nginx -g "daemon off;"
