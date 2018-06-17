# lo14

# Server side

To launch server :
`./vsh-server.sh <port> </path/to/archives> &`

# Client side

To launch client on "list" mode : 
`./vsh -list <server_ip_address> <port>`

To launch client on "browse" mode :
`./vsh -browse <server_ip_address> <port> <archive_name>`

To launch client on "extract" mode :
`./vsh -extract <server_ip_address> <port> <archive_name>`


# Necessary functions
	[x] List
	[o] Browse
		[x] pwd
		[x] cat
		    [x] Absolute
		    [x] Relative
		        [x] Forward
		        [x] Backward
		[x] cd
		    [x] Absolute path navigation
		    [x] Relative path navigation
		        [x] Forward navigation
		        [x] Backward navigation
		[o] rm
		    [o] Absolute
		        [x] File
		        [ ] Directory
		    [o] Relative
		        [o] Forward
                        [x] File
                        [ ] Directory
		        [o] Backward
                        [x] File
                        [ ] Directory
		[x] ls
		    [x] Absolute
		    [x] Relative
		        [x] Forward
		        [x] Backward
	[x] Extract
