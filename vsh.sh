#!/bin/bash

#####################################
#     Déclaration des fonctions     #
#####################################

# Envoi une commande au serveur et affiche la réponse ligne par ligne jusqu'à recontrer le texte "ENDRESPONSE"
function sendCommand {
	local line
	local msg
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
	echo -e "Connected to \e[92m\e[1m$ipAddress\e[0m on port \e[92m\e[1m$port\e[0m - Browsing archive \e[92m\e[1m$archive\e[0m."
	while [[ $userInputCommand != 'quit' ]]; do
		read -a userInputArray -p "vsh:$directory> "
		userInputCommand=${userInputArray[0]}
		userInputArray=("${userInputArray[@]:1}")
		case $userInputCommand in
			pwd) sendCommand $userInputCommand $directory;;
			ls) sendCommand $userInputCommand;;
			cd)
			    if [ -z "$userInputArray" ]; then
			        userInputArray="/"
			        directory=$(sendCommand $userInputCommand $archive $userInputArray $directory)
			    else
                    if [[ ! -z $(sendCommand $userInputCommand $archive $userInputArray $directory) ]]; then
                        directory=$(sendCommand $userInputCommand $archive $userInputArray $directory)
                    else
                        echo "cd: no such file or directory"
			        fi
			    fi
			   ;;
			cat)
			    #sendCommand $userInputCommand $archive $userInputArray $directory
                if [[ ! -z $(sendCommand $userInputCommand $archive $userInputArray $directory) ]]; then
                    sendCommand $userInputCommand $archive $userInputArray $directory
                else
                    echo "cat: no such file or directory"
			    fi
			   ;;
			rm) sendCommand $userInputCommand $archive $userInputArray $directory;;
			help) sendCommand $userInputCommand $archive;;
			stop) sendCommand $userInputCommand $archive;;
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
	#echo "extracting $archive !"
	sendCommand "extract" $archive > $archive.temp

	extract_dir=${archive::-5}
	base_folder=$(pwd)

	debut_header=$(head -n 1 $archive.temp | cut -d: -f1)
	debut_body=$(head -n 1 $archive.temp | cut -d: -f2)
	nb_lignes=$(wc -l $archive.temp | cut -d' ' -f1)
	#selection du header
	touch temp
	#echo "temp à été créé"
	touch header.temp
	#echo "header à été créé"
	head -n $(($debut_body-1)) $archive.temp > temp
	tail -n $(($debut_body-$debut_header)) temp > header.temp
	#selection du body
	touch body.temp
	#echo "body à été créé"
	tail -n $(($nb_lignes-$debut_body+1)) $archive.temp > temp
	cat temp > body.temp
	rm temp

	#Nécessaire pour calcul droit
	function testrights() {
		nb=0
		#echo "test : $1"
		if [[ $(echo $1 | grep "r") ]]
		then
			((nb=$nb+4))
			#echo "+4"
		fi
		if [[ $(echo $1 | grep "w") ]]
		then
			((nb=$nb+2))
			#echo "+2"
		fi
		if [[ $(echo $1 | grep "x") ]]
		then
			((nb=$nb+1))
			#echo "+1"
		fi
		echo $nb
	}

	#Fonction principale du calcul des droits des fichiers/dossiers
	function calculdroit () {
	if [ $# -eq 0 ]
	then
		echo "Il n'y a pas d'argument"
	else
		right=$1
		echo $line
		nbc=$(echo -n $right | wc -c)
		if [ $nbc -eq 9 ]
		then
			gp1=$(echo $right | sed 's/\(^...\).*/\1/')
			#echo "gp1 = $gp1"
			vgp1=$(testrights $gp1)
			#echo $vgp1

			gp2=$(echo $right | sed 's/^...\(...\).*/\1/')
			#echo "gp2 = $gp2"
			vgp2=$(testrights $gp2)
			#echo $vgp2

			gp3=$(echo $right | sed 's/.*\(...\)$/\1/')
			#echo "gp3 = $gp3"
			vgp3=$(testrights $gp3)
			#echo $vgp3

			((rights=$vgp1*100+$vgp2*10+$vgp3))
			echo $rights
		else
			echo "Les droits ne sont pas enregistrés correctement"
			echo "Veuillez les modifier au bon format"
		fi
	fi
	}

	#Nécessaire pour la fonction extract
	function makefile () {
		#echo $2
		touch $extract_dir/$2
		#echo "droit : $1"
		#echo $(calculdroit $1)
		somme=$(($3+$4-1))
		if [[ $4 -ne 0 ]]
		then
			cat body.temp | head -n $somme | tail -n $4 > $extract_dir/$2
		else
			touch $extract_dir/$2
		fi
		sudo chmod $(calculdroit $1) $extract_dir/$2
	}

	#Nécessaire pour la fonction extract
	function makedir () {
		#echo "dir"
		mkdir $extract_dir/$2
		#echo "droit : $1"
		#echo $(calculdroit $1)
		sudo chmod $(calculdroit $1) $extract_dir/$2
	}

	#Fonction principale de l'extraction des fichiers et dossiers de l'archives dans le dossier extraction
	function extract () {
		#Ici on vient récupérer l'arborescence racine contenant les dossiers 
		#de l'archive (contenu dans la première ligne directory)
		#Ensuite on créé les dossiers et on les place dans le bonne ordre.
		root_dir=$(cat header.temp | head -n 1 | cut -d' ' -f2 | sed 's/\(.*\)\/$/\1/')
		#echo $root_dir
		mkdir -p $extract_dir/$root_dir

		while read ligne; do
			if [[ $ligne =~ ^[^d] ]] && [[ $ligne =~ ^[^@] ]]
			then
				#emier caractère du paquets de droit afin de déterminer si on a un dossier ou un fichier
				dir=$(echo $ligne | cut -d ' ' -f2 | sed 's/^\(.\).*$/\1/g')
				#on récupère le gro
				#on récupère le prupe de droit sans le premier carctère
				rig=$(echo $ligne | cut -d ' ' -f2 | sed 's/^.\(.*\)/\1/g')
				#on récupère le nom du fichier
				name=$(echo $ligne | cut -d ' ' -f1)
				case $dir in
					-)#echo "c'est un ficier"
						#on récupère le caractère marquant le début du contenu dans le body
						d=$(echo $ligne | cut -d' ' -f4)
						#on récupère le carctère marquant la longueur du contenu
						f=$(echo $ligne | cut -d' ' -f5)
						makefile $rig $name $d $f;;
					d)#echo "c'est un dossier"
						makedir $rig $name;;
					*)echo "gros ton archive est foutu";;
				esac
			fi
		done < header.temp
	}

	#Fonction principale de "rangement" des fichiers extraits
	function placement () {
		changement="false"
		str=""
		while read line
		do
			if [ "$(echo -n $line)" == "@" ]
			then
				changement="false"	
				#echo $changement
				#appeler ici la fonction qui va bouger les fichiers dans les dossiers
				cd $extract_dir
				
				for i in $str
				do
				
					if [ -f $i ]
					then
						echo $i
						mv $i $active_dir/$i
					fi
					
					if [ -d $i ]
					then 
						echo $i
						mv $i $active_dir/$i
					fi
					
				done
				
				cd ..
				#echo "str : $str"
				str=""
			fi
			
			if [ $changement == "true" ]
			then
				#ici si la variable changement est à true on envoie le nom du fichier
				#dans la variable $str 
				str="$str $(echo $line | cut -d' ' -f1)"
				#echo "changement=true"
			fi
			
			if [ $(echo $line | cut -d' ' -f1) == "directory" ]
			then
				#ici si on se trouve sur une ligne qui commance par directory, elle va forcément indiquer
				#le nom du dossier et sa place dans l'arborescence
				#on vient donc récupérer le nom du dossier et le placer dans la variable $active_dir
				#sed 's/^.*\/\?\([A-Za-z0-9_]*\)\/$/a\1/'
				
				active_dir=$(echo $line | cut -d ' ' -f2)
				
				if [ $(echo $active_dir | sed 's/.*\(.\)$/\1/') == "/" ]
				then
					active_dir=$(echo $active_dir | sed 's/\(.*\).$/\1/')
				fi
				
				#echo "dir : $active_dir"
				changement="true"
				#echo $changement
			fi
			
		done < header.temp
		echo $str
	}
	extract
	placement
	rm $base_folder/header.temp $base_folder/body.temp $base_folder/$archive.temp
}

# Fonction permettant d'envoyer un message au serveur, lui demandant de retourner les archives présesntes
function list {
	sendCommand "list"
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
