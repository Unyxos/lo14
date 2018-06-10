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


#####################################
#       Browse mode functions       #
#####################################

# Displays path to current directory
function commande-pwd {
    echo "$1"
}

# Handles navigation in the archive using both relative and absolute paths
function commande-cd {
    local archive asked_dir cur_dir header fin_header archive base_dir
    archive=$1
    asked_dir=$2
    cur_dir=$3

    # $base_dir it the root folder of the archive using archive's layout. For example, if the first line of our
    # archive's header is "directory Exemple/Test/", then "Exemple/Test/" will be our root directory which contains
    # all the content.
    base_dir=$(echo $(head -n $(head -n 1 Test.arch |cut -d: -f1) Test.arch |grep -o "\w*/$"))

    # Checks if specified path ends with a "/", if it does, we simply remove it
    function checkAskedDir {
        if [[ ! -z $(echo "$asked_dir" |grep "/$") ]]; then
            asked_dir=${asked_dir::-1}
        fi
    }

    # Stores all archive header's content in a $header variable used to perform tests
    fin_header=$(head -n 1 $archive | cut -d: -f2)
    fin_header=$((fin_header - 1))
    for i in `seq $(head -n 1 $archive | cut -d: -f1) $fin_header`; do
        header="$header$(head -n $i $archive | tail -n+$i)\n"
    done

    case $asked_dir in
    # Returns to root directory
    /)
        echo "/"
       ;;

    # Absolute navigation
    /*)
        checkAskedDir
        #Remove the "/" at the beginning so it can be searched in $header
        asked_dir=${asked_dir:1}

        # Checks if asked directory exists in the header of the specified archive file
        # If it does, it simply returns asked directory's path, if not, returns nothing to display error on client side
        if [[ ! -z $(echo -e "$header" |grep "^directory $base_dir$asked_dir/*$") ]]; then
            echo "/$asked_dir"
        else
            echo ""
        fi
       ;;

    # Relative backward navigation
    ..*)
        local dots_nb paths_to_backward test finalDir
        dots_nb=$(echo $asked_dir |grep -o "\." |wc -l)
        paths_to_backward=$((dots_nb/2))

        # Check if the number of "." is odd or even, if odd, returns nothing to display error on client side
        if (( $dots_nb % 2 )); then
            echo ""
        else
            # If $asked_dir does not end by a "/", we add one, it's necessary for next verifications
            if [[ -z $(echo $asked_dir |grep "/$") ]]; then
                asked_dir="$asked_dir/"
            fi

            # When I wrote this, only God and I understood what I was doing
            # Now, God only knows
            # TODO: retrouver l'utilité de cette fonction
            function double_dots {
                local slashNumber dirToTest
                slashNumber=$(echo $cur_dir |grep -o "/" |wc -l)
                dirToTest="$(echo "$cur_dir" | cut -d/ -f-$slashNumber)"
                if [[ -z $dirToTest ]]; then
                    echo "/"
                else
                    echo "$dirToTest"
                fi
            }

            # Defines $cur_dir on something that must be useful.. let's try to guess what
            # TODO: cf todo plus haut
            for i in $(seq 1 $paths_to_backward); do
                cur_dir=$(double_dots)
            done

            # Checks if $asked_dir is only made of "../" or "..", if it does, returns $cur_dir to client
            if [[ -z $(echo $asked_dir |sed 's/\.\.\///g') ]]; then
                echo "$cur_dir"
            # If it doesn't, check if asked path exists
            else
                # Removes all ".." and "../" from asked dir and gives this value to $asked_dir for next tests
                asked_dir=$(echo $asked_dir |sed 's/\.\.\///g')
                asked_dir=${asked_dir::-1}
                cur_dir=${cur_dir:1}

                # If $cur_dir is empty, it means we're at the beginning of our archive and we test from there
                if [[ -z "$cur_dir" ]]; then
                    # Checks if asked directory exists starting from the beginning of our archive, if it does,
                    # we returns path starting from /, nothing if it doesn't
                    if [[ ! -z $(echo -e "$header" |grep "^directory $base_dir$asked_dir/*$") ]]; then
                        echo "/$asked_dir"
                    else
                        echo ""
                    fi
                # If $cur_dir isn't empty, it means we're in an existing folder so we include this in our verification
                else
                    # Checks if asked directory exists starting from the current directory in our archive, if it does,
                    # we returns path starting from /$cur_dir, nothing if it doesn't
                    if [[ ! -z $(echo -e "$header" |grep "^directory $base_dir$cur_dir/$asked_dir/*$") ]]; then
                        echo "/$cur_dir/$asked_dir"
                    else
                        echo ""
                    fi
                fi
            fi
        fi
       ;;
    #Relative forward navigation
    *)
        checkAskedDir
        cur_dir=${cur_dir:1}
        # Checks if $cur_dir's length is equal to 0, if it is, performs a check based on $base_dir and $asked_dir.
        if [[ $(echo ${#cur_dir}) -eq 0  ]]; then
            # If the association of $base_dir and $asked_dir exists in the header, returns /$asked_dir, nothing if not.
            if [[ ! -z $(echo -e "$header" |grep "^directory $base_dir$asked_dir/*$") ]]; then
                echo "/$asked_dir"
            else
                echo ""
            fi
        # If not, means we're already in a directory and not at the root directory, so performs check using $base_dir,
        # $cur_dir and $asked_dir.
        else
            # If the association of $cur_dir, $base_dir and $asked_dir exists in the header,
            # returns $base_dir$cur_dir/$asked_dir, nothing if not.
            if [[ ! -z $(echo -e "$header" |grep "^directory $base_dir$cur_dir/$asked_dir/*$") ]]; then
                echo "/$cur_dir/$asked_dir"
            else
                echo ""
            fi
        fi
       ;;
    esac
}

# Displays content of current directory by default or specified directory if entered, on client side
function commande-ls {
    echo 'ls: not working yet!'
    echo $*
    #TODO : Commande ls
}

# Stops the server
function commande-stop {
    kill -9 $(lsof -t -i:$PORT)
    kill -9 $$
    exit 1
}

# Displays content of specified file
function commande-cat {
    echo 'cat: not working yet!'
    #TODO : Commande cat
}

# Removes specified file(s) and directory(ies)
function commande-rm {
    echo 'rm: not working yet!'
    #TODO : Commande rm
}

# Displays help on client side
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

#####################################
#        List mode function         #
#####################################
# Displays list of available archives on client side
function commande-list {
    echo -e "Available archives:"
    ls | grep ".arch"
}

#####################################
#       Extract mode function       #
#####################################
# Returns specified archive's content to client
function commande-extract {
    echo "$(<$1)"
}

# Accepts and handles all incoming connections
accept-loop