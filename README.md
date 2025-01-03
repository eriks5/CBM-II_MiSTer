# [CBM-II](https://github.com/eriks5/CBM-II_MiSTer/) for [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

MiSTer FPGA core for the [Commodore CBM-II line of 8-bit computers](http://cbmsteve.ca/cbm2/index.html)
(aka. PET-II, P128, B128, B256, P500/B600/B700 series)

![CBM-II Family photo](https://github.com/eriks5/CBM-II_MiSTer/blob/master/b3.jpg?raw=true)

## Core Features

* Business (80-column monochrome) and Professional (40 column colour with VIC-II) models
* 128kB, 256kB or full memory (~1MB) options
* VIC-II (P500 model) or 6545 CRTC (B600/B700 models) video
* SID audio
* Predefined and custom model configurations
* Direct file injection (*.PRG)
* Joystick/paddle/mouse support (P500 model)
* 4040/8250 IEEE disk drives (supporting D64, D80 and D82 disk images)
* Optional external RAM in segment 15.
* Optional external ROM at location $2000, $4000 and $6000 in segment 15.
* External IEC through USER_IO port (requires modified kernal or external ROM)

### Disk support

Core supports D64, D80 and D82 disk images through two 4040 and 8250 IEEE dual-disk drives. 
When using a D80 disk image, the first disk access will result in an error. 
This is normal behaviour of the 8250 drive.

## Keyboard

![keyboard-mapping](https://github.com/eriks5/CBM-II_MiSTer/blob/master/keyboard.png?raw=true)

The following PC keys are mapped to the special CBM-II keys:

* <kbd>End</kbd> &rArr; <kbd>RUN STOP</kbd>
* <kbd>PgUp</kbd> &rArr; <kbd>OFF RVS</kbd>
* <kbd>PgDn</kbd> &rArr; <kbd>NORM GRAPH</kbd>
* <kbd>Delete</kbd> &rArr; <kbd>CE</kbd>
* <kbd>F11</kbd> &rArr; <kbd>C=</kbd>
* <kbd>Alt</kbd>+Numpad <kbd>0</kbd> &rArr; <kbd>00</kbd>
* <kbd>Alt</kbd>+Numpad <kbd>/</kbd> &rArr; <kbd>?</kbd>

## Acknowlegements

This core could not exist without the following projects:

* The MiSTer project
* T65, (c) 2002-2015 Daniel Wallner, Mike Johnson, Wolfgang Scherr, Morten Leikvoll
* VIC-II, from FPGA64 by Peter Wendrich (pwsoft@syntiac.com)
* MC6845, from BBC Micro for Altera DE1 (c) 2011 Mike Stirling
* SID, from C64_MiSTer by Sorgelig
* VIA6522, (C) 2011, Thomas Skibo
* MOS6526, by Rayne
* M6532, from k7800 (c) by Jamie Blanks
* MOS6551, from CoCo3FPGA (c) 2008 Gary Becker (gary_l_becker@yahoo.com)
* C1351 Mouse, from C64_MiSTer by Sorgelig

Most of these projects include changes contributed by other authors.
See the source code for the full copyright notices.
