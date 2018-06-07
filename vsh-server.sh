#! /bin/bash

# Ce script implémente un serveur.
# Le script doit être invoqué avec l'argument :
# PORT   le port sur lequel le serveur attend ses clients
if [ $# -ne 2 ]; then
    echo -e "usage: $(basename $0) <port> <chemin vers les archives>\nExemple : $(basename $0) 1337 /home/test"
    exit -1
fi

PORT="$1"

# Déclaration du tube
FIFO="/tmp/$USER-fifo-$$"


# Il faut détruire le tube quand le serveur termine pour éviter de
# polluer /tmp.  On utilise pour cela une instruction trap pour être sur de
# nettoyer même si le serveur est interrompu par un signal.
function nettoyage() { rm -f "$FIFO"; }
trap nettoyage EXIT

# on crée le tube nommé
[ -e "$FIFO" ] || mkfifo "$FIFO"

function accept-loop() {
    while true; do
        interaction < "$FIFO" | netcat -l -k -p "$PORT" > "$FIFO"
    done
}

# La fonction interaction lit les commandes du client sur entrée standard
# et envoie les réponses sur sa sortie standard.
#
#   CMD arg1 arg2 ... argn
#
# alors elle invoque la fonction :
#
#         commande-CMD arg1 arg2 ... argn
#
# si elle existe; sinon elle envoie une réponse d'erreur.
function interaction() {
    local cmd args
    while true; do
        read cmd args || exit -1
        fun="commande-$cmd"
        #echo $fun
        if [ "$(type -t $fun)" = "function" ]; then
            $fun $args
            echo "ENDRESPONSE"
        else
            commande-non-comprise $fun $args
        fi
    done
}

# Les fonctions implémentant les différentes commandes du serveur
function commande-non-comprise () {
    echo "Le serveur ne peut pas interpreter cette commande"
}

# Fonctions pour le mode "browse"
#Affiche le répertoire courant
function commande-pwd {
    echo "$1"
}

function commande-cd {
    function getHeader {
        local header fin_header archive
        archive=$1
        fin_header=$(head -n 1 $archive | cut -d: -f2)
        fin_header=$((fin_header - 1))
        for i in `seq $(head -n 1 $archive | cut -d: -f1) $fin_header`; do
            header="$header$(head -n $i $archive | tail -n+$i)\n"
        done
        echo -e "$header"
    }
    local archive asked_dir cur_dir
    archive=$1
    asked_dir=$2
    cur_dir=$3
    #echo "===================================="
    #echo "Asked directory : $asked_dir"
    #echo "Current directory : $cur_dir"
    #echo "Browsed archive : $archive"
    #echo "===================================="

    case $asked_dir in
    #Return to root directory
    /)
        echo "/"
       ;;
    #Absolute navigation
    /*)
        #Remove the "/" at the beginning so it can be searched in $header
        asked_dir=${asked_dir:1}

        header=getHeader $archive

        if [[ ! -z $(echo -e "$header" |grep "^directory $asked_dir$") ]]; then
            echo "/$asked_dir"
        else
            echo ""
        fi
       ;;
    #Going backwards
    ..*)
        echo "retour en arrière"
       ;;
    #Relative navigation
    *)

       ;;
    esac
}

function commande-ls {
    echo 'ls: not working yet!'
    echo $*
}

function commande-stop {
    kill -9 $(lsof -t -i:$PORT)
    kill -9 $$
    exit 1
}
function commande-cat {
    echo 'cat: not working yet!'
}

function commande-rm {
    echo 'rm: not working yet!'
}

function commande-help {
    echo -e "                       \e[92m#\e[95m#\e[91m# \e[39mList of commands \e[91m#\e[95m#\e[92m#\e[39m"
    echo ""
    echo -e "  cat         <filename>               Display content of a file"
    echo -e "  cd          <path_to_directory>      Move to the specified directory"
    echo -e "  ls     [-l]                          List files and folders in the current directory"
    echo -e "  pwd                                  Display absolute path to current directory"
    echo -e "  quit                                 Exit VSH client"
    echo -e "  rm     [-r] <filename_or_dirname>    Remove specified folder(s) or file(s)"
}

# Affiche la liste des archives disponibles
function commande-list {
    echo -e "Available archives:"
    ls | grep ".arch"
}

# Renvoi le contenu du fichier Test.arch (à modifier plus tard!)
function commande-extract {
    echo "$(<$1)"
}
# On accepte et traite les connexions
accept-loop