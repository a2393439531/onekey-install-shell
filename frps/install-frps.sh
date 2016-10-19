#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS Debian or Ubuntu (32bit/64bit)
#   Description:  A tool to auto-compile & install frps on Linux
#   Author: Clang
#   Intro:  http://koolshare.cn/forum-72-1.html
#===============================================================================================
program_name="frps"
version="1.2"
str_program_dir="/usr/local/${program_name}"
program_releases="https://api.github.com/repos/fatedier/frp/releases"
program_api_filename="/tmp/${program_name}_api_file.txt"
program_init="/etc/init.d/${program_name}"
program_config_file="frps.ini"
program_init_download_url=https://raw.githubusercontent.com/clangcn/onekey-install-shell/master/frps/frps.init
str_install_shell=https://raw.githubusercontent.com/clangcn/onekey-install-shell/master/frps/install-frps.sh

function fun_clangcn(){
    echo ""
    echo "+---------------------------------------------------------+"
    echo "|        frps for Linux Server, Written by Clang          |"
    echo "+---------------------------------------------------------+"
    echo "|     A tool to auto-compile & install frps on Linux      |"
    echo "+---------------------------------------------------------+"
    echo "|    Intro: http://koolshare.cn/thread-65379-1-1.html     |"
    echo "+---------------------------------------------------------+"
    echo ""
}
function fun_set_text_color(){
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}
# Check if user is root
function rootness(){
    if [[ $EUID -ne 0 ]]; then
        fun_clangcn
        echo "Error:This script must be run as root!" 1>&2
        exit 1
    fi
}
function get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
# Check OS
function checkos(){
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        OS=CentOS
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        OS=Debian
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        OS=Ubuntu
    else
        echo "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}
# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}
# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi
}
# Check OS bit
function check_os_bit(){
    ARCHS=""
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
        Is_64bit='y'
        ARCHS="amd64"
    else
        Is_64bit='n'
        ARCHS="386"
    fi
}
function check_centosversion(){
if centosversion 5; then
    echo "Not support CentOS 5.x, please change to CentOS 6,7 or Debian or Ubuntu and try again."
    exit 1
fi
}
# Disable selinux
function disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}
# Random password
function fun_randstr(){
  index=0
  strRandomPass=""
  for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {1..32}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
  echo $strRandomPass
}
# ====== check packs ======
function check_net-tools(){
    netstat -V >/dev/null
    if [[ $? -gt 6 ]] ;then
        echo " Run net-tools failed"
        if [ "${OS}" == 'CentOS' ]; then
            echo " Install centos net-tools ..."
            yum -y install net-tools
        else
            echo " Install debian/ubuntu net-tools ..."
            apt-get update -y
            apt-get install -y net-tools
        fi
    fi
    echo $result
}
function fun_getVer(){
    program_version=""
    program_latest_filename=""
    echo -e "Loading network version for ${program_name}, please wait..."
    rm -f ${program_api_filename}
    wget --no-check-certificate -qO- ${program_releases} > ${program_api_filename}
    if [ -s ${program_api_filename} ]; then
        program_version=`cat ${program_api_filename} | grep \"tag_name\" | cut -d\" -f4 | head -n 1`
        program_latest_filename=`cat ${program_api_filename} | grep \"name\" | grep frp_${program_version:1}_linux_${ARCHS} | cut -d\" -f4 | head -n 1`
        program_latest_file_url=`cat ${program_api_filename} | grep \"browser_download_url\" | grep ${program_version}/frp_${program_version:1}_linux_${ARCHS} | cut -d\" -f4`
        if [ -z "${program_latest_file_url}" ]; then
            echo -e "${COLOR_RED}Load network version failed!!!${COLOR_END}"
        else
            echo -e "${program_name} Latest release file ${COLOR_GREEN}${program_latest_filename}${COLOR_END}"
        fi
    else
        echo -e "${COLOR_RED}Load ${program_name} release file failed!!!${COLOR_END}"
    fi
    rm -f ${program_api_filename}
}
function fun_download_file(){
    # download
    if [ ! -s ${str_program_dir}/${program_name} ]; then
        rm -fr ${program_latest_filename} frp_${program_version:1}_linux_${ARCHS}
        if ! wget --no-check-certificate -q ${program_latest_file_url} -O ${program_latest_filename}; then
            echo -e " ${COLOR_RED}failed${COLOR_END}"
            exit 1
        fi
        tar xzf ${program_latest_filename}
        mv frp_${program_version:1}_linux_${ARCHS}/frps ${str_program_dir}/${program_name}
        rm -fr ${program_latest_filename} frp_${program_version:1}_linux_${ARCHS}
    fi
    chown root:root -R ${str_program_dir}
    if [ -s ${str_program_dir}/${program_name} ]; then
        [ ! -x ${str_program_dir}/${program_name} ] && chmod 755 ${str_program_dir}/${program_name}
    else
        echo -e " ${COLOR_RED}failed${COLOR_END}"
        exit 1
    fi
}
# Check port
function fun_check_port(){
    port_flag=""
    strCheckPort=""
    input_port=""
    port_flag="$1"
    strCheckPort="$2"
    if [ ${strCheckPort} -ge 1 ] && [ ${strCheckPort} -le 65535 ]; then
        checkServerPort=`netstat -ntulp | grep "\b:${strCheckPort}\b"`
        if [ -n "${checkServerPort}" ]; then
            echo ""
            echo -e "${COLOR_RED}Error:${COLOR_END} Port ${COLOR_GREEN}${strCheckPort}${COLOR_END} is ${COLOR_PINK}used${COLOR_END},view relevant port:"
            netstat -ntulp | grep "\b:${strCheckPort}\b"
            fun_input_${port_flag}_port
        else
            input_port="${strCheckPort}"
        fi
    else
        echo "Input error! Please input correct numbers."
        fun_input_${port_flag}_port
    fi
}
function fun_check_number(){
    num_flag=""
    strMaxNum=""
    strCheckNum=""
    input_number=""
    num_flag="$1"
    strMaxNum="$2"
    strCheckNum="$3"
    if [ ${strCheckNum} -ge 1 ] && [ ${strCheckNum} -le ${strMaxNum} ]; then
        input_number="${strCheckNum}"
    else
        echo "Input error! Please input correct numbers."
        fun_input_${num_flag}
    fi
}
# input port
function fun_input_bind_port(){
    def_server_port="5443"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}bind_port${COLOR_END} [1-65535]"
    read -p "(Default Server Port: ${def_server_port}):" serverport
    [ -z "${serverport}" ] && serverport="${def_server_port}"
    fun_check_port "bind" "${serverport}"
}
function fun_input_dashboard_port(){
    def_dashboard_port="6443"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}dashboard_port${COLOR_END} [1-65535]"
    read -p "(Default dashboard_port: ${def_dashboard_port}):" input_dashboard_port
    [ -z "${input_dashboard_port}" ] && input_dashboard_port="${def_dashboard_port}"
    fun_check_port "dashboard" "${input_dashboard_port}"
}
function fun_input_vhost_http_port(){
    def_vhost_http_port="80"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhost_http_port${COLOR_END} [1-65535]"
    read -p "(Default vhost_http_port: ${def_vhost_http_port}):" input_vhost_http_port
    [ -z "${input_vhost_http_port}" ] && input_vhost_http_port="${def_vhost_http_port}"
    fun_check_port "vhost_http" "${input_vhost_http_port}"
}
function fun_input_vhost_https_port(){
    def_vhost_https_port="443"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhost_https_port${COLOR_END} [1-65535]"
    read -p "(Default vhost_https_port: ${def_vhost_https_port}):" input_vhost_https_port
    [ -z "${input_vhost_https_port}" ] && input_vhost_https_port="${def_vhost_https_port}"
    fun_check_port "vhost_https" "${input_vhost_https_port}"
}
function fun_input_log_max_days(){
    def_max_days="30"
    def_log_max_days="3"
    echo ""
    echo -e "Please input ${program_name} ${COLOR_GREEN}log_max_days${COLOR_END} [1-${def_max_days}]"
    read -p "(Default log_max_days: ${def_log_max_days} day):" input_log_max_days
    [ -z "${input_log_max_days}" ] && input_log_max_days="${def_log_max_days}"
    fun_check_number "log_max_days" "${def_max_days}" "${input_log_max_days}"
}
function fun_input_max_pool_count(){
    def_max_pool="200"
    def_max_pool_count="50"
    echo ""
    echo -e "Please input ${program_name} ${COLOR_GREEN}max_pool_count${COLOR_END} [1-${def_max_pool}]"
    read -p "(Default max_pool_count: ${def_max_pool_count}):" input_max_pool_count
    [ -z "${input_max_pool_count}" ] && input_max_pool_count="${def_max_pool_count}"
    fun_check_number "max_pool_count" "${def_max_pool}" "${input_max_pool_count}"
}
function pre_install_clang(){
    fun_clangcn
    echo -e "Check your server setting, please wait..."
    checkos
    check_centosversion
    check_os_bit
    disable_selinux
    if [ -s ${str_program_dir}/${program_name} ] && [ -s ${program_init} ]; then
        echo "${program_name} is installed!"
    else
        check_net-tools
        clear
        fun_clangcn
        fun_getVer
        echo -e "Loading You Server IP, please wait..."
        defIP=$(wget -qO- ip.clang.cn | sed -r 's/\r//')
        echo -e "You Server IP:${COLOR_GREEN}${defIP}${COLOR_END}"
        echo -e  "${COLOR_YELOW}Please input your server setting:${COLOR_END}"
        fun_input_bind_port
        [ -n "${input_port}" ] && set_bind_port="${input_port}"
        echo "${program_name} bind_port: ${set_bind_port}"
        echo ""
        fun_input_dashboard_port
        [ -n "${input_port}" ] && set_dashboard_port="${input_port}"
        echo "${program_name} dashboard_port: ${set_dashboard_port}"
        echo ""
        fun_input_vhost_http_port
        [ -n "${input_port}" ] && set_vhost_http_port="${input_port}"
        echo "${program_name} vhost_http_port: ${set_vhost_http_port}"
        echo ""
        fun_input_vhost_https_port
        [ -n "${input_port}" ] && set_vhost_https_port="${input_port}"
        echo "${program_name} vhost_https_port: ${set_vhost_https_port}"
        echo ""
        default_privilege_token=`fun_randstr`
        read -p "Please input privilege_token (Default: ${default_privilege_token}):" set_privilege_token
        [ -z "${set_privilege_token}" ] && set_privilege_token="${default_privilege_token}"
        echo "${program_name} privilege_token: ${set_privilege_token}"
        echo ""
        fun_input_max_pool_count
        [ -n "${input_number}" ] && set_max_pool_count="${input_number}"
        echo "${program_name} max_pool_count: ${set_max_pool_count}"
        echo ""
        echo "##### Please select log_level #####"
        echo "1: info"
        echo "2: warn"
        echo "3: error"
        echo "4: debug"
        echo "#####################################################"
        read -p "Enter your choice (1, 2, 3, 4 or exit. default [1]): " str_log_level
        case "${str_log_level}" in
            1|[Ii][Nn][Ff][Oo])
                str_log_level="info"
                ;;
            2|[Ww][Aa][Rr][Nn])
                str_log_level="warn"
                ;;
            3|[Ee][Rr][Rr][Oo][Rr])
                str_log_level="error"
                ;;
            4|[Dd][Ee][Bb][Uu][Gg])
                str_log_level="debug"
                ;;
            [eE][xX][iI][tT])
                exit 1
                ;;
            *)
                str_log_level="info"
                ;;
        esac
        echo "log_level: ${str_log_level}"
        echo ""
        fun_input_log_max_days
        [ -n "${input_number}" ] && set_log_max_days="${input_number}"
        echo "${program_name} log_max_days: ${set_log_max_days}"
        echo ""
        echo "##### Please select log_file #####"
        echo "1: enable"
        echo "2: disable"
        echo "#####################################################"
        read -p "Enter your choice (1, 2 or exit. default [1]): " str_log_file
        case "${str_log_file}" in
            1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
                str_log_file="./frps.log"
                str_log_file_flag="enable"
                ;;
            0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
                str_log_file="/dev/null"
                str_log_file_flag="disable"
                ;;
            [eE][xX][iI][tT])
                exit 1
                ;;
            *)
                str_log_file="./frps.log"
                str_log_file_flag="enable"
                ;;
        esac
        echo "log_file: ${str_log_file_flag}"
        echo ""
        echo "============== Check your input =============="
        echo -e "You Server IP   : ${COLOR_GREEN}${defIP}${COLOR_END}"
        echo -e "Bind port       : ${COLOR_GREEN}${set_bind_port}${COLOR_END}"
        echo -e "Dashboard port  : ${COLOR_GREEN}${set_dashboard_port}${COLOR_END}"
        echo -e "vhost http port : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}"
        echo -e "vhost https port: ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}"
        echo -e "Privilege token : ${COLOR_GREEN}${set_privilege_token}${COLOR_END}"
        echo -e "Max Pool count  : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}"
        echo -e "Log level       : ${COLOR_GREEN}${str_log_level}${COLOR_END}"
        echo -e "Log max days    : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}"
        echo -e "Log file        : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}"
        echo "=============================================="
        echo ""
        echo "Press any key to start...or Press Ctrl+c to cancel"

        char=`get_char`
        install_program_server_clang
    fi
}
# ====== install server ======
function install_program_server_clang(){
    [ ! -d ${str_program_dir} ] && mkdir -p ${str_program_dir}
    cd ${str_program_dir}
    echo "${program_name} install path:$PWD"

    echo -n "config file for ${program_name} ..."
# Config file
cat > ${str_program_dir}/${program_config_file}<<-EOF
# [common] is integral section
[common]
# A literal address or host name for IPv6 must be enclosed
# in square brackets, as in "[::1]:80", "[ipv6-host]:http" or "[ipv6-host%zone]:80"
bind_addr = 0.0.0.0
bind_port = ${set_bind_port}
# if you want to configure or reload frps by dashboard, dashboard_port must be set
dashboard_port = ${set_dashboard_port}
# dashboard assets directory(only for debug mode)
# assets_dir = ./static

vhost_http_port = ${set_vhost_http_port}
vhost_https_port = ${set_vhost_https_port}
# console or real logFile path like ./frps.log
log_file = ${str_log_file}
# debug, info, warn, error
log_level = ${str_log_level}
log_max_days = ${set_log_max_days}
# if you enable privilege mode, frpc can create a proxy without pre-configure in frps when privilege_token is correct
privilege_mode = true
privilege_token = ${set_privilege_token}
# only allow frpc to bind ports you list, if you set nothing, there won't be any limit
#privilege_allow_ports = 1-65535
# pool_count in each proxy will change to max_pool_count if they exceed the maximum value
max_pool_count = ${set_max_pool_count}

EOF
    echo " done"

    echo -n "download ${program_name} ..."
    rm -f ${str_program_dir}/${program_name} ${program_init}
    fun_download_file
    echo " done"
    echo -n "download ${program_init}..."
    if [ ! -s ${program_init} ]; then
        if ! wget --no-check-certificate -q ${program_init_download_url} -O ${program_init}; then
            echo -e " ${COLOR_RED}failed${COLOR_END}"
            exit 1
        fi
    fi
    [ ! -x ${program_init} ] && chmod +x ${program_init}
    echo " done"

    echo -n "setting ${program_name} boot..."
    [ ! -x ${program_init} ] && chmod +x ${program_init}
    if [ "${OS}" == 'CentOS' ]; then
        chmod +x ${program_init}
        chkconfig --add ${program_name}
    else
        chmod +x ${program_init}
        update-rc.d -f ${program_name} defaults
    fi
    echo " done"
    [ -s ${program_init} ] && ln -s ${program_init} /usr/bin/${program_name}
    ${program_init} start
    fun_clangcn
    #install successfully
    echo ""
    echo "Congratulations, ${program_name} install completed!"
    echo "=============================================="
    echo -e "You Server IP   : ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e "Bind port       : ${COLOR_GREEN}${set_bind_port}${COLOR_END}"
    echo -e "Dashboard port  : ${COLOR_GREEN}${set_dashboard_port}${COLOR_END}"
    echo -e "vhost http port : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}"
    echo -e "vhost https port: ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}"
    echo -e "Privilege token : ${COLOR_GREEN}${set_privilege_token}${COLOR_END}"
    echo -e "Max Pool count  : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}"
    echo -e "Log level       : ${COLOR_GREEN}${str_log_level}${COLOR_END}"
    echo -e "Log max days    : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}"
    echo -e "Log file        : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}"
    echo "=============================================="
    echo -e "${program_name} Dashboard  : ${COLOR_GREEN}http://${defIP}:${set_dashboard_port}/${COLOR_END}"
    echo "=============================================="
    echo ""
    echo -e "${program_name} status manage: ${COLOR_PINKBACK_WHITEFONT}${program_name}${COLOR_END} {${COLOR_GREEN}start|stop|restart|status|config|version${COLOR_END}}"
    echo -e "Example:"
    echo -e "  start: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}start${COLOR_END}"
    echo -e "   stop: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}stop${COLOR_END}"
    echo -e "restart: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}restart${COLOR_END}"
    exit 0
}
############################### configure function ##################################
function configure_program_server_clang(){
    if [ -s ${str_program_dir}/${program_config_file} ]; then
        vi ${str_program_dir}/${program_config_file}
    else
        echo "${program_name} configuration file not found!"
        exit 1
    fi
}
############################### uninstall function ##################################
function uninstall_program_server_clang(){
    fun_clangcn
    if [ -s ${program_init} ] || [ -s ${str_program_dir}/${program_name} ] ; then
        echo "============== Uninstall ${program_name} =============="
        str_uninstall="n"
        echo -n -e "${COLOR_YELOW}You want to uninstall?${COLOR_END}"
        read -p "[y/N]:" str_uninstall
        case "${str_uninstall}" in
        [yY]|[yY][eE][sS])
        echo ""
        echo "You select [Yes], press any key to continue."
        str_uninstall="y"
        char=`get_char`
        ;;
        *)
        echo ""
        str_uninstall="n"
        esac
        if [ "${str_uninstall}" == 'n' ]; then
            echo "You select [No],shell exit!"
        else
            checkos
            ${program_init} stop
            if [ "${OS}" == 'CentOS' ]; then
                chkconfig --del ${program_name}
            else
                update-rc.d -f ${program_name} remove
            fi
            rm -f ${program_init} /var/run/${program_name}.pid /usr/bin/${program_name}
            rm -fr ${str_program_dir}
            echo "${program_name} uninstall success!"
        fi
    else
        echo "${program_name} Not install!"
    fi
    exit 0
}
############################### update function ##################################
function update_program_server_clang(){
    fun_clangcn
    if [ -s ${program_init} ] || [ -s ${str_program_dir}/${program_name} ] ; then
        echo "============== Update ${program_name} =============="
        checkos
        check_centosversion
        check_os_bit
        remote_shell_version=`wget --no-check-certificate -qO- ${str_install_shell} | sed -n '/'^version'/p' | cut -d\" -f2`
        remote_init_version=`wget --no-check-certificate -qO- ${program_init_download_url} | sed -n '/'^version'/p' | cut -d\" -f2`
        local_init_version=`sed -n '/'^version'/p' ${program_init} | cut -d\" -f2`
        install_shell=${strPath}
        update_flag="false"
        if [ ! -z ${remote_shell_version} ] || [ ! -z ${remote_init_version} ];then
            if [[ "${local_init_version}" < "${remote_init_version}" ]];then
                echo "========== Update ${program_name} ${program_init} =========="
                if ! wget --no-check-certificate ${program_init_download_url} -O ${program_init}; then
                    echo "Failed to download ${program_name}.init file!"
                    exit 1
                else
                    echo -e "${COLOR_GREEN}${program_init} Update successfully !!!${COLOR_END}"
                    update_flag="true"
                fi
            fi
            if [[ "${version}" < "${remote_shell_version}" ]];then
                echo "========== Update ${program_name} install-${program_name}.sh =========="
                if ! wget --no-check-certificate ${str_install_shell} -O ${install_shell}/$0; then
                    echo "Failed to download $0 file!"
                    exit 1
                else
                    echo -e "${COLOR_GREEN}$0 Update successfully !!!${COLOR_END}"
                    update_flag="true"
                fi
            fi
            if [ "${update_flag}" == 'true' ]; then
                echo -e "${COLOR_GREEN}Update shell successfully !!!${COLOR_END}"
                echo ""
                echo -e "${COLOR_GREEN}Please Re-run${COLOR_END} ${COLOR_PINKBACK_WHITEFONT}$0 update${COLOR_END}"
                echo ""
                exit 1
            fi
        fi
        if [ "${update_flag}" == 'false' ]; then
            [ ! -d ${str_program_dir} ] && mkdir -p ${str_program_dir}
            echo -e "Loading network version for ${program_name}, please wait..."
            fun_getVer >/dev/null 2>&1
            local_program_version=`${str_program_dir}/${program_name} --version`
            echo -e "${COLOR_GREEN}${program_name}  local version ${local_program_version}${COLOR_END}"
            echo -e "${COLOR_GREEN}${program_name} remote version ${program_version:1}${COLOR_END}"
            if [[ "${local_program_version}" < "${program_version:1}" ]];then
                echo -e "${COLOR_GREEN}Found a new version,update now!!!${COLOR_END}"
                ${program_init} stop
                sleep 1
                rm -f /usr/bin/${program_name} ${str_program_dir}/${program_name}
                fun_download_file
                if [ "${OS}" == 'CentOS' ]; then
                    chmod +x ${program_init}
                    chkconfig --add ${program_name}
                else
                    chmod +x ${program_init}
                    update-rc.d -f ${program_name} defaults
                fi
                [ -s ${program_init} ] && ln -s ${program_init} /usr/bin/${program_name}
                [ ! -x ${program_init} ] && chmod 755 ${program_init}
                ${program_init} start
                echo "${program_name} version `${str_program_dir}/${program_name} --version`"
                echo "${program_name} update success!"
            else
                 echo -e "no need to update !!!${COLOR_END}"
            fi
        fi
    else
        echo "${program_name} Not install!"
    fi
    exit 0
}
clear
strPath=`pwd`
rootness
fun_set_text_color
# Initialization
action=$1
[  -z $1 ]
case "$action" in
install)
    pre_install_clang 2>&1 | tee /root/${program_name}-install.log
    ;;
config)
    configure_program_server_clang
    ;;
uninstall)
    uninstall_program_server_clang 2>&1 | tee /root/${program_name}-uninstall.log
    ;;
update)
    update_program_server_clang 2>&1 | tee /root/${program_name}-update.log
    ;;
*)
    fun_clangcn
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|update|config}"
    RET_VAL=1
    ;;
esac
