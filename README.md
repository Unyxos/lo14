# lo14

# Server side

To launch server :
`./vsh-server.sh <port> </path/to/archives>`

# Client side

To launch client on "list" mode : 
`./vsh -list <server_ip_address> <port>`

To launch client on "browse" mode :
`./vsh -list <server_ip_address> <port> <archive_name>`

To launch client on "extract" mode :
`./vsh -extract <server_ip_address> <port> <archive_name>`


# Necessary functions
	[x] List
	[ ] Browse
		[x] pwd
		[ ] cat
		[ ] cd
		[ ] rm
		[ ] ls
	[x] Extract