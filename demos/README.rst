On UN*X
-------

ULX3S
-----

Graphic
-------


What it does ?
~~~~~~~~~~~~~~

Load and image on SDRAM throught serial port and display it by ULX3S' HDMI.

What do I need to run it ?
~~~~~~~~~~~~~~~~~~~~~~~~~~

Install Imagemagick https://imagemagick.org to convert *your_image.your_format*

Download https://github.com/hdl4fpga/hdl4fpga.github.io/raw/master/demos/graphic/ULX3S/bits/demos_graphic-12F.bit

Open a console on demos directory and run

IMAGE="*your_image_path*/*your_image.your_format*" PROG="ujprog *your_bit_path*/demos_graphic-12F.bit" ./demos.sh

I'm curious : Where is the project file ?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

https://github.com/hdl4fpga/hdl4fpga/blob/work/ULX3S/diamond/demos.ldf

Enjoy it!