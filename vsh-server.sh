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

function absolute_path {
    local asked_dir
    asked_dir=$1
    # Checks if specified path ends with a "/", if it does, we simply remove it
    if [[ ! -z $(echo "$asked_dir" |grep "/$") ]]; then
        asked_dir=${asked_dir::-1}
    fi
    #Remove the "/" at the beginning so it can be searched in $header
    asked_dir=${asked_dir:1}

    # Checks if asked directory exists in the header of the specified archive file
    # If it does, it simply returns asked directory's path, if not, returns nothing to display error on client side
    if [[ ! -z $(echo -e "$header" |grep "^directory $base_dir$asked_dir/*$") ]]; then
        echo "/$asked_dir"
    else
        echo ""
    fi
}

function relative_backward_path {
    local dots_nb paths_to_backward test asked_dir
    asked_dir=$1
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

        # Removes "../" everytime the function is called and returns or /, or the new directory
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

        # Defines $cur_dir on double_dots() result
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
}

function relative_forward_path {
    local asked_dir
    asked_dir=$1

    # Verifies if $asked_dir starts with a /, if not, we add it
    if [[ ${asked_dir:0:1} == "/" ]]; then
        asked_dir="/$asked_dir"
    fi

    # Checks if specified path ends with a "/", if it does, we simply remove it
    if [[ ! -z $(echo "$asked_dir" |grep "/$") ]]; then
        asked_dir=${asked_dir::-1}
    fi

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
}

function getHeader {
    local archive fin_header header
    archive=$1
    # Stores all archive header's content in a $header variable used to perform tests
    fin_header=$(head -n 1 $archive | cut -d: -f2)
    fin_header=$((fin_header - 1))
    for i in `seq $(head -n 1 $archive | cut -d: -f1) $fin_header`; do
        header="$header$(head -n $i $archive | tail -n+$i)\n"
    done
    echo -e "$header"
}

function getBody {
    local archive body_start body_end body
    archive=$1
    # Saves body start line and body end line
    body_start=$(head -n 1 $archive | cut -d: -f2)
    body_end=$(cat $archive | wc -l)
    body_end=$((body_end+1))
    for i in `seq $body_start $body_end`; do
        body="$body$(head -n $i $archive | tail -n+$i)\n"
    done
    echo -e "$body"
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
    base_dir=$(echo $(head -n $(head -n 1 $archive |cut -d: -f1) $archive |grep -o "\w*/$"))

    # Stores all archive header's content in a $header variable used to perform tests
    header=$(getHeader $archive)

    case $asked_dir in
    # Returns to root directory
    /)
        echo "/"
       ;;

    # Absolute navigation
    /*)
        absolute_path $asked_dir
       ;;

    # Relative backward navigation
    ..*)
        relative_backward_path $asked_dir
       ;;
    #Relative forward navigation
    *)
        relative_forward_path $asked_dir
       ;;
    esac
}

# Displays content of current directory by default or specified directory if entered, on client side
function commande-ls {
    local archive asked_dir header fin_header archive base_dir nb_slash body_start body body_length modified_file_dir cur_dir header base_dir
    local body_length content_list lines_number
    archive=$1
    asked_dir=$2
    cur_dir=$3
    header=$(getHeader $archive)

    function getContentList {
        lines_number=$(echo -e "$header" |wc -l)
        for i in `seq "1" $lines_number`; do
            # If the file rights contains a "d" it's a folder
            if [[ ! -z $(echo -e "$header" |sed -n "$i"p |cut -d " " -f2 |grep "d") ]]; then
                #echo "directory"
                content_list="$content_list$(echo -e "$header" |sed -n "$i"p |cut -d " " -f1)/ "
            else
                #echo "not directory"
                if [[ ! -z $(echo -e "$header" |sed -n "$i"p |cut -d " " -f2 |grep "x") ]]; then
                    #echo "can be executed"
                    content_list="$content_list$(echo -e "$header" |sed -n "$i"p |cut -d " " -f1)* "
                else
                    #echo "can't be executed"
                    content_list="$content_list$(echo -e "$header" |sed -n "$i"p |cut -d " " -f1) "
                fi
            fi
        done

        echo -e "$content_list"
    }

    base_dir=$(echo $(head -n $(head -n 1 $archive |cut -d: -f1) $archive |grep -o "\w*/$"))

    # Checks if $file_dir starts with a letter/number or if it's empty to go in forward relative "navigation"
    if [[ $asked_dir =~ ^[A-Za-z] || $asked_dir =~ ^[0-9] || ${#asked_dir} == "0" ]]; then
        if [[ ${#asked_dir} == "0" ]]; then
            file_dir="/"
        fi
        # Verifies if $cur_dir contains "/" and if $file_dir contains more than 1 "/"
        if [[ $(echo $cur_dir) =~ ^/$ && $(echo $asked_dir |grep -o "/") > 1 ]]; then
            cur_dir=${cur_dir:1}
            asked_dir="$cur_dir"
        # Verifies if $modified_file_dir is equal to one or if $cur_dir contains nothing
        elif [[ "$modified_file_dir" != "1" || ${#cur_dir} == "0" ]]; then
            cur_dir=${cur_dir:1}
            asked_dir="$cur_dir/$asked_dir"
            # Removes "/" from $file_dir if it exists at the first position
            if [[ $(echo ${asked_dir:0:1}) == "/" ]]; then
                asked_dir=${asked_dir:1}
            fi
        fi
        # If $file_dir is just 1 character long or if the function is working we continue our tests further
        if [[ ${#asked_dir} == "1" || ! -z $(relative_forward_path $asked_dir) ]]; then
            local file_infos
            if [[ "$asked_dir" != */ ]]; then
                asked_dir="$asked_dir/"
            fi
            header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $asked_dir |sed 's/\//\\\//g')*$/d" |sed "/\@/q" |sed "/\@/d")
            getContentList
        else
            echo "ls: no such file or directory"
        fi
    # Checks if first char from file_dir are "/", if yes, go through absolute "navigation"
    elif [ ${asked_dir:0:1} == "/" ]; then
        # Checks if specified directory exists
        if [[ ${#asked_dir} == "1" && "$asked_dir" == "/" ]]; then
            asked_dir=""
        fi
        if [[ ! -z $(absolute_path $asked_dir) ]]; then
            local file_infos
            asked_dir=${asked_dir:1}
            # Gets all content of $file_dir repertory
            header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $asked_dir |sed 's/\//\\\//g')$/d" |sed "/\@/q" |sed "/\@/d")
            getContentList
        else
            echo "ls: no such file or directory"
        fi
    # Checks if first 3 chars from file_dir are "../", if yes, go through relative backward "navigation"
    elif [ ${asked_dir:0:3} == "../" ]; then
        echo "relative backward"
        dots_nb=$(echo $file_dir |grep -o "\." |wc -l)
        paths_to_backward=$((dots_nb/2))

        # Removes "../" everytime the function is called and returns or /, or the new directory
        function double_dots_cat {
            local slashNumber dirToTest
            slashNumber=$(echo $cur_dir |grep -o "/" |wc -l)
            dirToTest="$(echo "$cur_dir" | cut -d/ -f-$slashNumber)"
            if [[ -z $dirToTest ]]; then
                echo "/"
            else
                echo "$dirToTest"
            fi
        }

        # Defines $cur_dir on double_dots_cats() result
        for i in $(seq 1 $paths_to_backward); do
            cur_dir=$(double_dots_cat)
        done
        cur_dir=${cur_dir:1}
        # Checks if directory exists
        if [[ ! -z $(relative_backward_path $cur_dir) ]]; then
            local file_infos
            # Checks if the file contains only "../", if it does, user won't go further in folders and we verify using $cur_dir
            if [[ -z $(echo $asked_dir |sed 's/\.\.\///g') ]]; then
                header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $cur_dir |sed 's/\//\\\//g')\/*$/d" |sed "/\@/q" |sed "/\@/d")
            # If it doesn't, check if asked path exists
            else
                local remain_dir
                # Removes all "../" and last "/" from $file_dir and contains it in $remain_dir
                remain_dir=${asked_dir//..\//}
                remain_dir=${remain_dir::-1}
                header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $remain_dir |sed 's/\//\\\//g')\/*$/d" |sed "/\@/q" |sed "/\@/d")
            fi
            # Verifies is $asked_file exists in the list in $header
            if [[ ! -z $(echo -e "$header" |grep "^$asked_file ") ]]; then
                file_infos=$(echo -e "$header" |grep "$asked_file ")
                # Verifies if asked resource is a directory or a file
                if [[ -z $(echo -e "$file_infos" |cut -d " " -f2 |grep "d") ]]; then
                    local file_start file_length file_content
                    # Checks if the file have 4 spaces between it's information, if it does, it contains data
                    if [[ $(echo "$file_infos" |grep -o " "| wc -l) == "4" ]]; then
                        # Iterates in body to get all file's content
                        file_start=$(echo "$file_infos" | cut -d " " -f4)
                        file_length=$(echo "$file_infos" | cut -d " " -f5)
                        if [[ "$file_length" < "1" ]]; then
                            file_end=$(($file_start+$file_length))
                        else
                            file_end=$(($file_start+$file_length-1))
                        fi
                        for j in `seq $file_start $file_end`; do
                            file_content="$file_content$(echo -e "$body" |sed -n "$j"p)\n"
                        done
                        # Prints content
                        echo -ne "$file_content"
                    # If not, returns nothing
                    else
                        echo ""
                    fi
                else
                    echo "cat: $asked_file: Is a directory"
                fi
            else
                echo "cat: no such file or directory"
            fi
        else
            echo "cat: no such file or directory"
        fi
    fi
}

# Stops the server
function commande-stop {
    kill -9 $(lsof -t -i:$PORT)
    kill -9 $$
    exit 1
}

# Displays content of specified file
function commande-cat {
    local archive asked_file file_dir cur_dir header fin_header archive base_dir nb_slash body_start body body_length modified_file_dir
    local body_length
    archive=$1
    asked_file=$2
    cur_dir=$3

    # $base_dir it the root folder of the archive using archive's layout. For example, if the first line of our
    # archive's header is "directory Exemple/Test/", then "Exemple/Test/" will be our root directory which contains
    # all the content.
    base_dir=$(echo $(head -n $(head -n 1 $archive |cut -d: -f1) $archive |grep -o "\w*/$"))

    if [[ -z $(echo "$asked_file" |grep "/") ]]; then
        file_dir="$cur_dir/$file_dir"
        modified_file_dir="1"
    fi

    # If $asked_file beginning isn't "/" or "../", defines $file_dir on $cur_dir minus it's first character
    if [ ${asked_file:0:1} != "/" -a ${asked_file:0:3} != "../" ]; then
        file_dir="${cur_dir:1}"
    fi

    # If $asked_file contains "/" we separate the resource's directory and the resource's name in 2 variables
    if [[ ! -z $(echo $asked_file |grep "/") ]]; then
        file_dir="$asked_file"
        nb_slash=$(echo "$asked_file" |grep -o "/" |wc -l)
        nb_slash=$(($nb_slash + 1))
        asked_file=$(echo "$asked_file" | cut -d "/" -f$nb_slash)
        file_dir=${file_dir::-${#asked_file}}
    fi

    header=$(getHeader $archive)

    body=$(getBody $archive)

    # Checks if $file_dir starts with a letter/number or if it's empty to go in forward relative "navigation"
    if [[ $file_dir =~ ^[A-Za-z] || $file_dir =~ ^[0-9] || ${#file_dir} == "0" ]]; then
        if [[ ${#file_dir} == "0" ]]; then
            file_dir="/"
        fi
        # Verifies if $cur_dir contains "/" and if $file_dir contains more than 1 "/"
        if [[ $(echo $cur_dir) =~ ^/$ && $(echo $file_dir |grep -o "/") > 1 ]]; then
            cur_dir=${cur_dir:1}
            file_dir="$cur_dir"
        # Verifies if $modified_file_dir is equal to one or if $cur_dir contains nothing
        elif [[ "$modified_file_dir" != "1" || ${#cur_dir} == "0" ]]; then
            cur_dir=${cur_dir:1}
            file_dir="$cur_dir/$file_dir"
            # Removes "/" from $file_dir if it exists at the first position
            if [[ $(echo ${file_dir:0:1}) == "/" ]]; then
                file_dir=${file_dir:1}
            fi
        fi
        # If $file_dir is just 1 character long or if the function is working we continue our tests further
        if [[ ${#file_dir} == "1" || -z $(relative_forward_path $file_dir) ]]; then
            local file_infos
            if [[ "$file_dir" != */ ]]; then
                file_dir="$file_dir/"
            fi
            header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $file_dir |sed 's/\//\\\//g')*$/d" |sed "/\@/q" |sed "/\@/d")
            # Verifies is $asked_file exists in the list in $header
            if [[ ! -z $(echo -e "$header" |grep "^$asked_file ") ]]; then
                file_infos=$(echo -e "$header" |grep "$asked_file ")
                # Verifies if asked resource is a directory or a file
                if [[ -z $(echo -e "$file_infos" |cut -d " " -f2 |grep "d") ]]; then
                    local file_start file_length file_content
                    # Checks if the file have 4 spaces between it's information, if it does, it contains data
                    if [[ $(echo "$file_infos" |grep -o " "| wc -l) == "4" ]]; then
                        file_start=$(echo "$file_infos" | cut -d " " -f4)
                        file_length=$(echo "$file_infos" | cut -d " " -f5)
                        if [[ "$file_length" < "1" ]]; then
                            file_end=$(($file_start+$file_length))
                        else
                            file_end=$(($file_start+$file_length-1))
                        fi
                        for j in `seq $file_start $file_end`; do
                            file_content="$file_content$(echo -e "$body" |sed -n "$j"p)\n"
                        done
                        echo -ne "$file_content"
                    else
                        echo ""
                    fi
                else
                    echo "cat: $asked_file: Is a directory"
                fi
            else
                echo "else 2"
            fi
        else
            echo "else 1"
        fi
    # Checks if first char from file_dir are "/", if yes, go through absolute "navigation"
    elif [ ${file_dir:0:1} == "/" ]; then
        # Checks if specified directory exists
        if [[ ! -z $(absolute_path $file_dir) ]]; then
            local file_infos
            file_dir=${file_dir:1}
            # Gets all content of $file_dir repertory
            header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $file_dir |sed 's/\//\\\//g')*$/d" |sed "/\@/q" |sed "/\@/d")
            # Checks if $asked_file exists in the list stored in $header
            if [[ ! -z $(echo -e "$header" |grep "^$asked_file ") ]]; then
                file_infos=$(echo -e "$header" |grep "$asked_file ")
                # Verifies if asked resource is a directory or a file
                if [[ -z $(echo -e "$file_infos" |cut -d " " -f2 |grep "d") ]]; then
                    local file_start file_length file_content
                    # Checks if the file have 4 spaces between it's information, if it does, it contains data
                    if [[ $(echo "$file_infos" |grep -o " "| wc -l) == "4" ]]; then
                        file_start=$(echo "$file_infos" | cut -d " " -f4)
                        file_length=$(echo "$file_infos" | cut -d " " -f5)
                        if [[ "$file_length" < "1" ]]; then
                            file_end=$(($file_start+$file_length))
                        else
                            file_end=$(($file_start+$file_length-1))
                        fi
                        for j in `seq $file_start $file_end`; do
                            file_content="$file_content$(echo -e "$body" |sed -n "$j"p)\n"
                        done
                        echo -ne "$file_content"
                    # If not, returns nothing
                    else
                        echo ""
                    fi
                else
                    echo "cat: $asked_file: Is a directory"
                fi
            else
                echo "cat: no such file or directory"
            fi
        else
            echo "cat: no such file or directory"
        fi
    # Checks if first 3 chars from file_dir are "../", if yes, go through relative backward "navigation"
    elif [ ${file_dir:0:3} == "../" ]; then
        dots_nb=$(echo $file_dir |grep -o "\." |wc -l)
        paths_to_backward=$((dots_nb/2))

        # Removes "../" everytime the function is called and returns or /, or the new directory
        function double_dots_cat {
            local slashNumber dirToTest
            slashNumber=$(echo $cur_dir |grep -o "/" |wc -l)
            dirToTest="$(echo "$cur_dir" | cut -d/ -f-$slashNumber)"
            if [[ -z $dirToTest ]]; then
                echo "/"
            else
                echo "$dirToTest"
            fi
        }

        # Defines $cur_dir on double_dots_cats() result
        for i in $(seq 1 $paths_to_backward); do
            cur_dir=$(double_dots_cat)
        done
        cur_dir=${cur_dir:1}
        # Checks if directory exists
        if [[ ! -z $(relative_backward_path $cur_dir) ]]; then
            local file_infos
            # Checks if the file contains only "../", if it does, user won't go further in folders and we verify using $cur_dir
            if [[ -z $(echo $file_dir |sed 's/\.\.\///g') ]]; then
                header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $cur_dir |sed 's/\//\\\//g')\/*$/d" |sed "/\@/q" |sed "/\@/d")
            # If it doesn't, check if asked path exists
            else
                local remain_dir
                # Removes all "../" and last "/" from $file_dir and contains it in $remain_dir
                remain_dir=${file_dir//..\//}
                remain_dir=${remain_dir::-1}
                header=$(echo -e "$header" |sed "0,/^directory $(echo $base_dir |sed 's/\//\\\//g')$(echo $remain_dir |sed 's/\//\\\//g')\/*$/d" |sed "/\@/q" |sed "/\@/d")
            fi
            # Verifies is $asked_file exists in the list in $header
            if [[ ! -z $(echo -e "$header" |grep "^$asked_file ") ]]; then
                file_infos=$(echo -e "$header" |grep "$asked_file ")
                # Verifies if asked resource is a directory or a file
                if [[ -z $(echo -e "$file_infos" |cut -d " " -f2 |grep "d") ]]; then
                    local file_start file_length file_content
                    # Checks if the file have 4 spaces between it's information, if it does, it contains data
                    if [[ $(echo "$file_infos" |grep -o " "| wc -l) == "4" ]]; then
                        # Iterates in body to get all file's content
                        file_start=$(echo "$file_infos" | cut -d " " -f4)
                        file_length=$(echo "$file_infos" | cut -d " " -f5)
                        if [[ "$file_length" < "1" ]]; then
                            file_end=$(($file_start+$file_length))
                        else
                            file_end=$(($file_start+$file_length-1))
                        fi
                        for j in `seq $file_start $file_end`; do
                            file_content="$file_content$(echo -e "$body" |sed -n "$j"p)\n"
                        done
                        # Prints content
                        echo -ne "$file_content"
                    # If not, returns nothing
                    else
                        echo ""
                    fi
                else
                    echo "cat: $asked_file: Is a directory"
                fi
            else
                echo "cat: no such file or directory"
            fi
        else
            echo "cat: no such file or directory"
        fi
    fi
}

# Removes specified file(s) and directory(ies)
function commande-rm {
    echo 'rm: not working yet!'
    #TODO : Commande rm
}

# Displays help on client side
function commande-help {
    echo -e "\e[92m#\e[95m#\e[91m# \e[39mList of commands \e[91m#\e[95m#\e[92m#\e[39m"
    echo ""
    echo -e "  cat         <filename>               Display content of a file"
    echo -e "  cd          <path_to_directory>      Move to the specified directory"
    echo -e "  ls                                   List files and folders in the current directory"
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