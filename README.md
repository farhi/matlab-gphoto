# matlab-gphoto
A Matlab interface for gPhoto to control camera/DSLR

We use the gphoto2 --shell mode:

Available commands:
	cd              Change to a directory on the camera
	lcd             Change to a directory on the local drive
	exit            Exit the gPhoto shell
	get             Download a file
	put             Upload a file
	get-thumbnail   Download a thumbnail
	get-raw         Download raw data
	show-info       Show image information, like width, height, and capture time
	delete          Delete
	mkdir           Create Directory
	rmdir           Remove Directory
	show-exif       Show EXIF information of JPEG images
	help            Displays command usage
	ls              List the contents of the current directory
	list-config     List configuration variables
	get-config      Get configuration variable
	set-config      Set configuration variable
	set-config-indexSet configuration variable index
	set-config-valueSet configuration variable
	capture-image   Capture a single image
	capture-image-and-downloadCapture a single image and download it
	capture-preview Capture a preview image
	wait-event      Wait for an event
	capture-tetheredWait for images to be captured and download it
	wait-event-and-downloadWait for events and images to be captured and download it
	q               Exit the gPhoto shell
	quit            Exit the gPhoto shell
	?               Displays command usage

