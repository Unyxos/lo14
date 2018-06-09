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
		[ ] cat
		[o] cd
		    [x] Absolute path navigation
		    [o] Relative path navigation
		        [x] Forward navigation
		        [] Backward navigation
		[ ] rm
		[ ] ls
	[x] Extract
