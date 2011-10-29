Torpedo
=======

Description
-----------

Fire when ready. Fast Ruby integration tests for OpenStack.

Installation
------------

	gem install torpedo

	#create the torpedo YAML config in your $HOME dir:
    cat > ~/.torpedo.conf <<"EOF_CAT"
	# YAML config file for torpedo

	# SERVER test settings
	test_create_image: false
	test_rebuild_server: false
	test_resize_server: false

	# IMAGES (Set one of the following)
	#image_name:
	#image_ref:

	# FLAVORS (Set one of the following)
	#flavor_name: 
	flavor_ref: 4

	# TIMEOUTS
	#ping_timeout: 60
	#ssh_timeout: 30

	# SSH KEYS (used to verify images which use an agent)
	#ssh_private_key: 
	#ssh_public_key: 

	# KEYPAIRS (used to verify AMI style images)
	keypair: test.pem
	keyname: test
	EOF_CAT


Examples
--------

Available torpedo tasks:

	Tasks:
	  torpedo all          # Run all tests.
	  torpedo fire         # Fire away! (alias for all)
	  torpedo flavors      # Run flavors tests for the OSAPI.
	  torpedo help [TASK]  # Describe available tasks or one specific task
	  torpedo images       # Run images tests for the OSAPI.
	  torpedo limits       # Run limits tests for the OSAPI.
	  torpedo servers      # Run servers tests for the OSAPI.

Run all tests:

	torpedo fire

Run all tests with debug HTTP request response output:

	DEBUG=true torpedo fire

Run all tests and output an Xunit style XML report:

	torpedo fire --xml-report=FILE

License
-------
Copyright (c) 2011 Dan Prince. See LICENSE.txt for further details.
