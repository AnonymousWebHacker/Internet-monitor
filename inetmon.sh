#!/bin/bash

# iNetMon v1.0 - Internet Monitor 4 GNU/Linux
# (c) 2018 AnonymousWebHacker
#

# TODO:
# - Logging to file
# - Proxy


# Tiempo de espera para comprobar el estado de la conexión. Si la conexión
# es muy inestable prueba aumentando este valor.
CHECK_TIMEOUT=10

# Utilizar cURL para hacer la comprobación, si es ´false´ se usará ICMP
USE_CURL=true

# Notificar usando un motor TTS (Text-To-Speech)
USE_TTS=false

# Indica si se debe mostrar la IP pública (no recomendado si tu conexión es lenta)
SHOW_PUBLIC_IP=true

# Servidor para obtener tu IP pública
PUBLIC_IP_SRV="http://api.ipify.org/"
#PUBLIC_IP_SRV="http://whatismyip.systutorials.com/myip/"

# Servidor para hacer la comprobación cuando se usa ICMP
#PING_CHECK_ADDRESS="8.8.8.8"
PING_CHECK_ADDRESS="127.0.0.1"


APP_TITLE="Internet Monitor 4 Linux"
LOG_FILE="//tmp/log/inetmon.log"
CURR_STATUS="unknown"
PUBLIC_IP='N/D'


function start {
	#print_banner

	log "Iniciando monitorización..." info

	if [[ $USE_CURL == false ]]; then
		log "Se está usando ICMP en lugar de CURL (no recomendado)." info
	fi

	# Main Loop
	while true; do
		if [[ $USE_CURL == true ]]; then
			# Verificar Internet usando HTTP
			http_check
		else
			# Verificar Internet usando ICMP
			ping -c 1 -W $CHECK_TIMEOUT -n "${PING_CHECK_ADDRESS}" >/dev/null 2>&1
		fi
		case $? in
			0) status "online";;
			1) status "offline";;
			*) status "error";;
		esac
		sleep 5s
	done
}

function status_changed {
	log "Status changed:$RED $CURR_STATUS" info
	
	if [[ $1 == 'online' ]]; then
		if [[ $SHOW_PUBLIC_IP == true ]]; then
			get_public_ip # Intenta obtener la IP pública
		fi
		local content="¡Estás conectado a Internet!\nTu IP pública es: $PUBLIC_IP"
		notify "$content" normal
		say "¡Estás conectado a Internet!"

	elif [[ $1 == 'offline' ]]; then
		local l_url="https://secure.etecsa.net:8443"
		local p_url="https://www.portal.nauta.cu/user/login"
		local content="¡No estás conectado a Internet!\n\n<a href=\"$l_url\">Inicia sesión</a>  <a href=\"$p_url\">Portal Usuario</a>"
		notify "$content" normal
		say "¡No estás conectado!"

	elif [[ $1 == 'error' ]]; then
		local content="¡Ha ocurrido un error de red!\nPuede que tu adaptador de red se encuentre desconectado o hayas perdido la conexión con tu ISP"
		notify "$content" low
		say "¡Error de conexión!"
	fi
}

# Establece el estado actual de la conexión sólo si es diferente
# Params: $1 nuevo estado
function status {
	if [[ $1 != $CURR_STATUS ]]; then
		CURR_STATUS=$1
		status_changed $CURR_STATUS
	fi
}

# Muestra una notificación con notify-send
# Params: $1 content, $2 urgency
function notify {
	local icon="$SCRIPT_DIR/assets/conn_status_$CURR_STATUS.png"
	local soundfile="$SCRIPT_DIR/sounds/$CURR_STATUS.wav"
	notify-send "${APP_TITLE}" "$1" -u "$2" --icon="$icon"
	aplay -N $soundfile >/dev/null 2>&1
}

# TTS
# Params: $1 text
function say {
	if [[ $USE_TTS == true ]]; then
		spd-say --language es --voice-type male2 -m some --volume -50 "$1"
	fi
}

function http_check {
	local html=$(curl -s -r 0-5 --connect-timeout $CHECK_TIMEOUT -L http://www.google.com/humans.txt)
	if [[ -n "$html" ]]; then
		# Detect WISPr
		if [[ ${html:24:12} = "CMCCWLANFORM" ]]; then
			return 1
		# Detect Internet
		elif [[ ${html} = "Google" ]]; then
			return 0
		fi	
	else
		return 2
	fi
}

# Obtiene la IP pública una vez (timeout 10 seg)
function get_public_ip {
	if [[ $PUBLIC_IP == 'N/D' ]]; then
		log "Obteniendo dirección IP pública..." info true
		PUBLIC_IP=$(curl -s --connect-timeout 10 -L $PUBLIC_IP_SRV)
		if [[ $? -eq 28 ]]; then # timeout
			PUBLIC_IP='N/D'
		fi
		echo -e "$RED $PUBLIC_IP$RESETCOLOR" >&2
	fi
}

# Imprime una línea del historial en la terminal
# Params $1 text, $2 type, $3 no newline
function log {
	local nonl=''
	#local timestamp="[$(date "+%F %X")]"
	if [[ $3 == true ]]; then
		nonl=-n
	fi
	case $2 in 
		info) local T="[$BLUE*$GREEN] $BLUE $1";;
		warn) local T="[$RED!$GREEN] $RED $1";;
	esac
	local logline="$BLUE$timestamp$GREEN $T $RESETCOLOR"
	echo -e $nonl $logline >&2
}

# for internal use only
export BLUE='\033[1;94m'
export GREEN='\033[1;92m'
export RED='\033[1;91m'
export RESETCOLOR='\033[1;00m'
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

function print_banner {
	reset
	echo -e "$RED
      __ _______         __   _______              
     |__|    |  |.-----.|  |_|   |   |.-----.-----.$GREEN
     |  |       ||  -__||   _|       ||  _  |     |$BLUE
     |__|__|____||_____||____|__|_|__||_____|__|__|

       $RED Internet Connection Monitor 4 GNU/Linux
	       $GREEN -- (c) 2018, AnonymousWebHacker -- $RESETCOLOR        
	" >&2
}

# Run Main Loop
start
