#! /bin/bash

# Ce script impl�mente un serveur.  
# Le script doit �tre invoqu� avec l'argument :                                                              
# PORT   le port sur lequel le serveur attend ses clients  
if [ $# -ne 2 ]; then
    echo -e "usage: $(basename $0) <port> <chemin vers les archives>\nExemple : $(basename $0) 1337 /home/test"
    exit -1
fi
PORT="$1"

# D�claration du tube
FIFO="/tmp/$USER-fifo-$$"


# Il faut d�truire le tube quand le serveur termine pour �viter de
# polluer /tmp.  On utilise pour cela une instruction trap pour �tre sur de
# nettoyer m�me si le serveur est interrompu par un signal.
function nettoyage() { rm -f "$FIFO"; }
trap nettoyage EXIT

# on cr�e le tube nomm�
[ -e "$FIFO" ] || mkfifo "$FIFO"

function accept-loop() {
    while true; do
        interaction < "$FIFO" | netcat -l -k -v -p "$PORT" > "$FIFO"
    done
}

# La fonction interaction lit les commandes du client sur entr�e standard 
# et envoie les r�ponses sur sa sortie standard. 
#
#   CMD arg1 arg2 ... argn                   
#                     
# alors elle invoque la fonction :
#                                                                            
#         commande-CMD arg1 arg2 ... argn                                      
#                                                                              
# si elle existe; sinon elle envoie une r�ponse d'erreur.                     
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

# Les fonctions impl�mentant les diff�rentes commandes du serveur
function commande-non-comprise () {
    echo "Le serveur ne peut pas interpreter cette commande"
}

# Fonctions pour le mode "browse"
#Affiche le r�pertoire courant
function commande-pwd {
    echo "$1"
}

function commande-cd {
    echo 'cd: not working yet!'
    echo "lol"
}

function commande-ls {
    echo 'ls: not working yet!'
    echo $*
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

# Renvoi le contenu du fichier Test.arch (� modifier plus tard!)
function commande-extract {
    echo "$(<Test.arch)"
}
# On accepte et traite les connexions
accept-loop