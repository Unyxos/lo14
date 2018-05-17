#!/bin/bash

#Affiche le répertoire courant
function pwd {
	echo "$1"
}

function  konami_code {
	echo "https://www.youtube.com/watch?v=CRkzItBabzs"
}

function ls {
	echo 'ls: not working yet!'
}

function cd {
	basedir="/"
	cur_dir=$2
	#dir=$(echo $ligne | cut -d ' ' -f2 | sed 's/^\(.\).*$/\1/g') ''''
	case $1 in
		# Si on commence par un "/" on vérifie si on souhaite retourner
		# à la racine ou simplement se déplacer par chemin absolu.
		/*)
			case "$1" in
				/ )
					echo "$basedir"
					;;
				/*)
					echo "$1"
					;;
			esac
			;;
		*)
			case "$1" in
				../*)
					#Si on se trouve à la racine on reste à la racine
					if [[ $cur_dir == "/" ]]; then
						echo "$basedir"
					#Sinon on change de répertoire si on le peut
					else
						echo "$1"
					fi
					;;
				*)
					echo "$basedir$1"
					;;
			esac
            ;;
	esac
}

function cat {
	echo 'cat: not working yet!'
}

function rm {
	echo 'rm: not working yet!'
}

function help {
	echo -e "                       \e[92m#\e[95m#\e[91m# \e[39mList of commands \e[91m#\e[95m#\e[92m#\e[39m"
	echo ""
	echo "  cat       <filename>             Display content of a file"
	echo "  cd        <path_to_directory>    Move to the specified directory"
	echo "  ls   [-l]                        List files and folders in the current directory"
	echo "  pwd                              Display absolute path to current directory"
	echo "  quit                             Exit VSH client"
	echo "  rm   [-r] <filename_or_dirname>  Remove specified folder(s) or file(s)"
}

#fonction permettant de lister les archives présentes sur le serveur
#En l'occurence, le serveur se trouve être un répertoire sur la machine locale.
function list {
    if [ -d "$1" ]
    then
        if [[ $2 =~ ^[0-9]+$ ]]
        then
            ls "$1" | grep ".arch"
        else
            echo "Le numéro de port sélectionné n'est pas correct ou n'est pas un numéro"
            exit 1
	fi
    else
        echo "Le serveur sélectionné n'existe pas"
		exit 1
    fi
}

#fonction permettant d'explorer l'archive en mode interactif
#nécessite la création d'un "shell"
function browse {
	if [ -d "$1" ]
        then
                if [[ $2 =~ ^[0-9]+$ ]]
                then
                	if [ -f "$3" ]
			then
				echo "Browse enable - Browsing $3"
				directory="/"
				while [[ $userInputCommand != 'quit' ]]; do
					read -a userInputArray -p "vsh:$directory> "
					userInputCommand=${userInputArray[0]}
					userInputArray=("${userInputArray[@]:1}")
					case $userInputCommand in
						pwd) pwd $directory;;
						ls) ls;;
						cd) directory=$(cd $userInputArray $directory);;
						#cd) cd $userInputArray $directory;;
						cat) cat;;
						rm) rm;;
						help) help;;
						quit) ;;
						upupdowndownleftrightleftrightba) konami_code;;
						*) echo -e "\e[91mUnknown command, please try another command or type \e[3m\e[1mhelp\e[0m\e[91m to get a list of commands and their usage.\e[39m"
					esac
					#echo "$directory"
				done
				echo "Good bye!"
				sleep 1
				clear
				exit 1
			else
				echo "L'archive sélectionnée n'existe pas"
			fi
                else
                        echo "Le numéro de port sélectionné n'est pas correct ou n'est pas un numéro"
                        exit 1
                fi
        else
                echo "Le serveur sélectionné n'existe pas"
                exit 1
        fi
}

#function extract {}

if [ $# -eq 0 ]
then
	echo "Il n'y a pas d'arguments"
else
	case $1 in
		-list) list "$2" "$3";;
		-browse) browse "$2" "$3" "$4";;
		-extract) ./extract "$2" "$3" "$4";;
		*) echo "Mauvais paramètre : veuillez choisir entre -list, -browse et -extract";;
	esac
fi
