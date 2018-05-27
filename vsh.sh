#!/bin/bash

#####################################
#     Déclaration des fonctions     #
#####################################

# Envoi un message au serveur et affiche la réponse ligne par ligne jusqu'à recontrer le texte "ENDRESPONSE"
function sendMessage {
	local line msg
	while read line; do
		if [[ $line == "ENDRESPONSE" ]]; then
			break
		else
			msg="$msg$line\n"
		fi
	done < <(netcat "$ipAddress" "$port" <<< "$*")
	echo "$(echo -e -n $msg)"
}

# Fonction gérant l'affichage du "shell" vsh, envoi un message au serveur suivant la commande entrée par l'utilisateur
function browse {
	directory="/"
	echo "Connected to server $ipAddress on port $port - Browsing archive $archive."
	while [[ $userInputCommand != 'quit' ]]; do
		read -a userInputArray -p "vsh:$directory> "
		userInputCommand=${userInputArray[0]}
		userInputArray=("${userInputArray[@]:1}")
		case $userInputCommand in
			pwd) sendMessage $userInputCommand $directory;;
			ls) sendMessage $userInputCommand;;
			#cd) directory=$(sendMessage $userInputCommand $userInputArray $directory);;
			cd) sendMessage $userInputCommand $userInputArray $directory;;
			cat) sendMessage $userInputCommand $userInputArray;;
			rm) sendMessage $userInputCommand $userInputArray;;
			help) sendMessage $userInputCommand;;
			quit) ;;
			*) echo -e "\e[91mUnknown command, please try another command or type \e[3m\e[1mhelp\e[0m\e[91m to get a list of commands and their usage.\e[39m"
		esac
	done
	echo "Good bye!"
	sleep 1
	clear
	exit 1
}

# Fonction permettant l'extraction
function extract {
	echo "extracting $archive !"
}

# Fonction permettant d'envoyer un message au serveur, lui demandant de retourner les archives présesntes
function list {
	sendMessage "list"
}

# Fonction affichant simplement comment utiliser la commande, à compléter
function usage {
	echo "usage"
}

#############################################################
#    Script principal appelant les fonctions précédentes    #
#############################################################

# Si $1 correspond soit à -browse, -list, ou -extract, on continue
if [[ $1 -eq "-browse" || $1 -eq "-list" || $1 -eq "-extract" ]]; then
	mode="$1" #On défini la variable mode sur le mode qui a été entré au lancement du client
	#On vérifie si l'adresse a un pattern d'adresse IP
	if [[ $2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || $2 = ^[a-zA-Z]+$ ]]; then
		ipAddress="$2" #On défini la variable ipAddress sur l'adresse qui a été entrée en paramètre
		if [[ $3 =~ ^[0-9]+$ ]]; then
			port="$3" #On défini la variable port sur le port qui a été entrée en paramètre
			#echo "$mode"
			#echo "$ipAddress"
			#echo "$port"
			archive="$4"
			case $mode in
				"-browse" ) browse;;
				"-extract" ) extract;;
				"-list" ) list;;
				* ) usage;;
			esac

		else
			echo "Le port entré n'est pas correct"
		fi
	else
		echo "Ceci n'est pas une adresse"
	fi
else
	echo "mauvais mode sélectionné"
fi
