# ******************************************************************************
# Copyright (C) 2015 Michael R. Ferrara, All rights reserved.
#
# Santa Rosa, CA 95404
# Tel:(707)536-1330
#
# Control USB Attenuator/Switch/Stacklight microcontroller
# via packet protocol over bulk channel
#
# code lives here: https://github.com/mikef5410/USB_Attenuator_Switch_Stacklight.git
#
package AttenSwitch;

#use Device::USB;
use USB::LibUSB;
use Moose;
use Moose::Exporter;
use MooseX::ClassAttribute;
use namespace::autoclean;

#use YAML::XS;
use Data::Dumper qw(Dumper);
## no critic (BitwiseOperators)
## no critic (ValuesAndExpressions::ProhibitAccessOfPrivateData)
## no critic (Variables::RequireLexicalLoopIterators)
#

=head1 NAME

AttenSwitch - Communicate with USB Attenuator/Switch/Stacklight driver via packet protocol over bulk channel

=head1 VERSION

VERSION 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

=over 4

  use strict;
  use warnings;
  use feature qw(switch);
  no warnings 'experimental';

  #Where to find our library and auxiliary code.
  use FindBin qw($Bin);
  use lib $ENV{ATTENSW} || "/projects/usbAtten_controller/perl";

  use lib "$Bin/..";
  use lib "$Bin";

  my $att = shift(@ARGV);

  use AttenSwitch;

  my $dut    = AttenSwitch->new(VIDPID => [0x4161,0x0003], SERIAL => "138001F0" );
  my $result = $dut->connect();
  if ( $result == AttenSwitch::SUCCESS ) {
     print("Got device\n");
  }

  my $attSel;

  given ($att) {
    when (0)  { $attSel = AttenSwitch::ATTEN->ATT_0DB; }
    when (10) { $attSel = AttenSwitch::ATTEN->ATT_10DB; }
    when (20) { $attSel = AttenSwitch::ATTEN->ATT_20DB; }
    when (30) { $attSel = AttenSwitch::ATTEN->ATT_30DB; }
    when (40) { $attSel = AttenSwitch::ATTEN->ATT_40DB; }
    when (50) { $attSel = AttenSwitch::ATTEN->ATT_50DB; }
    when (60) { $attSel = AttenSwitch::ATTEN->ATT_60DB; }
    when (70) { $attSel = AttenSwitch::ATTEN->ATT_70DB; }
  }
  $dut->atten($attSel);
  printf("ok\n");
  exit;

=back

=head1 DESCRIPTION

This module actually implements three different devices, a Stacklight driver, a step-attenuator driver, and a combo SP8T + SPDT driver.
The drivers are custom designed STM32F411 usb devices that identify with VID:0x4161, and PID:0x0001 for stacklight, 0x0002 for SP8T+SPDT,
and 0x0003 for attenuator. The devices also implement a CDC-ACM device and have a debug monitor running on that interface. The protocol 
used by this module is a simple COMMAND-RESPONSE packet protocol implemented on bulk endpoints 0x1/0x81.

Sources and HW design files live here: https://github.com/mikef5410/USB_Attenuator_Switch_Stacklight.git


=head1 Class Atributes

=over 4

=item *

B<validVidPids> - An array ref of Vids this module will recognize. Defaults to [ 0x4161, ]

=item *

B<validVidPids> - An array ref of [Vid,Pid]'s this module will recognize, Defaults to  [ [0x4161,0x00ff] , [0x4161,0x0003], [0x4161,0x0001], [0x4161,0x0002], [0x4161,0x0004] ] 

=back

=head1 Object Attributes

=over 4

=item *

B<dev> - The underlying USB device 

=item *

B<usb> - The underlying USB bus context (USB::LibUSB)

=item *

B<VIDPID> - A specific [VID,PID] to which we want to connect

=item *

B<SERIAL> - A specific USB serial number to which we want to connect

=item *

B<PRODINFO> - When connected, the device identity is queried, and this object reflects that info. It is
a AttenSwitch::ProdInfo object.

=item *

B<verbose> - Boolean, be talkative

=item *

B<timeout_ms> - Number, milliseconds of timeout. Defaults to 500ms

=item *

B<manufacturer> - Manufacturer string. My stuff returns "MF"

=item *

B<product> - Product string.


=back

=cut

# Class Attributes
class_has 'validVidPids' => (
  is      => 'ro',
  default => sub {
    [
      [ 0x4161, 0x00ff ],
      [ 0x4161, 0x0003 ],
      [ 0x4161, 0x0001 ],
      [ 0x4161, 0x0002 ],
      [ 0x4161, 0x0004 ],
      [ 0x4161, 0x0005 ],
      [ 0x4161, 0x0006 ],
    ]
  }
);

# Known devices:
#  0x00ff - unconfigured
#  0x0001 - USB Stacklight
#  0x0002 - MapleOLT serdes RF mux
#  0x0003 - USB Attenuator controller
#  0x0004 - USB Dual SPDT
#  0x0005 - USB air pressure sensor
#  0x0006 - USB 8769M Keysight 8769M SP6T
class_has 'SUCCESS'    => ( is => 'ro', default => 0 );
class_has 'FAIL'       => ( is => 'ro', default => -1 );
class_has 'CMD_OUT_EP' => ( is => 'rw', default => 0x1 );
class_has 'CMD_IN_EP'  => ( is => 'rw', default => 0x81 );
#
# Instance Attributes
has 'dev' => (
  is        => 'rw',
  predicate => 'connected',
  builder   => 'connect',
  lazy      => 1,
);
has 'handle' => ( is => 'rw', );
has 'usb' => (
  is      => 'rw',
  isa     => 'USB::LibUSB',
  default => sub { USB::LibUSB->init(); }
);
has 'VIDPID' => (
  is        => 'rw',
  isa       => 'ArrayRef',
  predicate => 'has_VIDPID',
);
has 'SERIAL' => (
  is        => 'rw',
  isa       => 'Str',
  predicate => 'has_SERIAL',
);
has 'PRODINFO' => (
  is  => 'rw',
  isa => 'AttenSwitch::ProdInfo'
);
has 'verbose' => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0
);
has 'timeout_ms' => (
  is      => 'rw',
  isa     => 'Int',
  default => 5000
);
has 'manufacturer' => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
);
has 'product' => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
);
has 'device' => (
  is      => 'rw',
  default => undef,
);
has 'eepromSize' => (
  is      => 'rw',
  isa     => "Int",
  default => 0x200,
);

=head2 METHODS

=over 4

=item B<< $attenswitch->connect() >> 

Find the usb device and get a connection to it. By specifying VID,PID,and SERIAL at construction (or some combination) you should
be able to talk to a specific device.

=back

=cut

sub connect {
  my $self = shift;
  my @ids  = $self->has_VIDPID() ? $self->VIDPID() : @{ AttenSwitch->validVidPids() };
  my $vid;
  my $pid;
  my $dev;
  my $handle;
  if ( defined( $self->device ) ) {
    $dev = $self->device;
    goto FOUND;
  }
  if ( $self->has_SERIAL ) {
    $handle = $self->usb->open_device_with_vid_pid_serial( $self->VIDPID->[0], $self->VIDPID->[1], $self->SERIAL );
  } elsif ( $self->has_VIDPID ) {
    $handle = $self->usb->open_device_with_vid_pid( $self->VIDPID->[0], $self->VIDPID->[1] );
  }
  if ( !defined($handle) ) {
    foreach my $id (@ids) {
      $handle = $self->usb->open_device_with_vid_pid( $self->VIDPID->[0], $self->VIDPID->[1] );
      last if ( defined($handle) );
    }    #next ID
  }
  if ( !defined $handle ) {
    print "ERROR: could not find any AttenSwitch devices \n";
    return AttenSwitch->FAIL;
  }
  $dev = $handle->get_device();
FOUND:
  $handle = $dev->open();
  $self->handle($handle);
  $self->dev($dev);
  my $desc = $dev->get_device_descriptor();
  $self->VIDPID( [ $desc->{idVendor}, $desc->{idProduct} ] );
  $self->SERIAL( $handle->get_string_descriptor_ascii( $desc->{iSerialNumber}, 64 ) );
  $self->manufacturer( $handle->get_string_descriptor_ascii( $desc->{iManufacturer}, 256 ) );
  $self->product( $handle->get_string_descriptor_ascii( $desc->{iProduct}, 256 ) );
  $self->handle->set_auto_detach_kernel_driver(1);

  if ( $self->verbose ) {
    printf( "Manufacturer   %s, %s \n",                $self->manufacturer(), $self->product() );
    printf( "Device         VID: %04X   PID: %04X \n", $self->VIDPID->[0],    $self->VIDPID->[1] );
  }
  my $cfg   = $dev->get_active_config_descriptor();
  my $numIf = $cfg->{bNumInterfaces};
  my $inter = $cfg->{interface}->[0]->[0];
  my $numEp = 0;
  if ( $self->verbose() ) {
    for ( my $if = 0 ; $if < $numIf ; $if++ ) {
      $inter = $cfg->{interface}->[$if]->[0];
      $numEp = $inter->{bNumEndpoints};
      printf( "Interface class 0x%x,  index %d, %d endpoints.\n", $inter->{bInterfaceClass}, $if, $numEp );
      printf("Endpoints      ");
      for ( my $epnum = 0 ; $epnum < $numEp ; $epnum++ ) {
        my $ep = $inter->{endpoint}->[$epnum];
        printf( "0x%02x   ", $ep->{bEndpointAddress} );
      }    #Loop over endpoints
      printf("\n");
    }    #Loop over interfaces
  }
  my $claim = $self->handle->claim_interface(0x2);    #Interface #2 is my command I/O interface
  printf("Claim returns  $claim \n") if ( $self->verbose() );
  $self->dev($dev);
  $self->PRODINFO( $self->identify );

  # $dev->close();
  return AttenSwitch->SUCCESS;
}

=over 4

=item B<< $attenswitch->disconnect() >> 

Notify USB subsystem you're no longer interested in this device interface.
You can do this when done with the device.

=back

=cut

sub disconnect {
  my $self = shift;
  $self->handle->release_interface(0x2);
  $self->handle->close();
  undef( $self->{dev} );
  undef( $self->{handle} );
}

=over 4

=item B<< ($err,$rxPacket) = $attenswitch->send_packet($txPacket) >> 

Low level send a packet to the device. $rxPacket and $txPacket are AttenSwitch::Packet objects.

$err will be either AttenSwitch->SUCCESS or AttenSwitch->FAIL.

=back

=cut

sub send_packet {
  my $self     = shift;
  my $packet   = shift;                        #AttenSwitch::Packet;
  my $rxPacket = AttenSwitch::Packet->new();
  if ( defined( $self->dev ) ) {
    if ( ref($packet) && $packet->isa("AttenSwitch::Packet") ) {

      #First, send out the packet ....
      my $txTot = 0;
      my $bytes = $packet->packet;
      my $notSent;
      do {
        my $ret = $self->handle->bulk_transfer_write( AttenSwitch->CMD_OUT_EP, $bytes, $self->timeout_ms );
        $txTot += $ret;
        $notSent = length( $packet->packet ) - $txTot;
        $bytes   = substr( $packet->packet, $txTot );
      } while ( $notSent > 0 );

      #Now, get the response packet
      my $rxbuf = "";
      my $ret;
      $rxbuf = $self->handle->bulk_transfer_read( AttenSwitch->CMD_IN_EP, 1024, $self->timeout_ms );
      $rxPacket->from_bytes($rxbuf);
      if ( $rxPacket->command->is_ack ) {
        return ( AttenSwitch->SUCCESS, $rxPacket );
      }
    }
  }
  return ( AttenSwitch->FAIL, $rxPacket );
}

=over 4

=item B<< $err = $attenswitch->sp8t($select) >> 

Set the SP8T switch. $select is an AttenSwitch::SP8TSETTING, a Class::Enum of: qw(J1 J2 J3 J4 J5 J6 J7 J8)

$err will be either AttenSwitch->SUCCESS or AttenSwitch->FAIL.

=back


=cut

sub sp8t {
  my $self   = shift;
  my $sel    = shift;                      #AttenSwitch::SP8TSETTING
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->SP8T,
    payload => pack( "C", $sel->ordinal )
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  return ($res);
}

=over 4

=item B<< $err = $attenswitch->sp6t($select) >> 

Set the Keysight 8769M SP6T switch. $select is an AttenSwitch::SP6TSETTING, a Class::Enum of: qw(J1 J2 J3 J4 J5 J6 )

$err will be either AttenSwitch->SUCCESS or AttenSwitch->FAIL.

=back


=cut

sub sp6t {
  my $self   = shift;
  my $sel    = shift;                      #AttenSwitch::SP8TSETTING
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->KS8769M,
    payload => pack( "C", $sel->ordinal )
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  return ($res);
}

=over 4

=item B<< $err = $attenswitch->spdt($switch, $select) >> 
 
Set one of the two available SPDTs. $switch is a AttenSwitch::SPDTSEL, a Class::Enum of: qw(SW1 SW2) and $select is a AttenSwitch::SPDTSETTING, a Class::Enum of qw(J1SEL J2SEL).

$err will be either AttenSwitch->SUCCESS or AttenSwitch->FAIL.

=back

=cut

sub spdt {
  my $self   = shift;
  my $sw     = shift;                      #AttenSwitch::SPDTSEL
  my $set    = shift;                      #AttenSwitch::SPDTSETTING
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->SPDT,
    payload => pack( "CC", $sw->ordinal, $set->ordinal )
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  return ($res);
}

=over 4

=item B<< $err = $attenswitch->atten($attenuation) >> 

Set a 0-70dB step attenuator. $attenuation is a AttenSwitch::ATTEN, a Class::Enum of: qw(ATT_0DB ATT_10DB ATT_20DB ATT_30DB ATT_40DB
ATT_50DB ATT_60DB ATT_70DB)

$err will be either AttenSwitch->SUCCESS or AttenSwitch->FAIL.

=back

=cut

sub atten {
  my $self   = shift;
  my $sel    = shift;                      #AttenSwitch::ATTEN
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->ATT,
    payload => pack( "C", $sel->ordinal )
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  return ($res);
}

=over 4

=item B<< $err = $attenswitch->stacklightNotify($color,$onTime,$offTime,$count) >> 

Command the stacklight to turn on a light. $color is a string: "r,y, or g" (multiple colors are OK), $onTime and $offTime are in milliseconds, and $count is the number of times to blink. A count of 0 is blink indefinitely. To extinguish, send a new notify with a short blink, and count of 1. If on time is 0, the color will be solid on indefinately. Turn all off with <C>stacklightNotify("g",1,1,1);</C>

$err will be either AttenSwitch->SUCCESS or AttenSwitch->FAIL.

=back

=cut

sub stacklightNotify {
  my $self    = shift;
  my $color   = uc(shift);
  my $onTime  = shift || 0;
  my $offTime = shift || 0;
  my $count   = shift || 0;
  my $col     = 0;
  $col |= 0x1 if ( $color =~ /R/ );
  $col |= 0x2 if ( $color =~ /Y/ );
  $col |= 0x4 if ( $color =~ /G/ );
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->NOTIFY,
    payload => pack( "CVVV", $col, $onTime, $offTime, $count )
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  return ($res);
}

=over 4

=item B<< $return = $attenswitch->dewpoint($temp,$rh) >> 

Return dewpoint from a temperature and rh%

=back

=cut

sub log10 {
  my $x = shift;
  return ( log($x) / log(10.0) );
}

sub dewpoint {
  my $self               = shift;
  my $temp               = shift;
  my $rh                 = shift;
  my $HSENSOR_CONSTANT_A = 8.1332;
  my $HSENSOR_CONSTANT_B = 1762.39;
  my $HSENSOR_CONSTANT_C = 235.66;
  if ( $rh > 0 ) {
    my $partialPressure = 10.0**( $HSENSOR_CONSTANT_A - $HSENSOR_CONSTANT_B / ( $temp + $HSENSOR_CONSTANT_C ) );
    my $dp =
      -$HSENSOR_CONSTANT_B / ( log10( $rh * $partialPressure / 100 ) - $HSENSOR_CONSTANT_A ) - $HSENSOR_CONSTANT_C;
    $dp = int( ( 100.0 * $dp ) + 0.5 ) / 100.0;
    return ($dp);
  } else {
    return (undef);
  }
}

=over 4

=item B<< $return = $attenswitch->getAmbientTHP() >> 

Reads ambient air temp, pressure and humidity. Returns [TempC,RH%,Pressure_mb]


=back

=cut

sub getAmbientTHP {
  my $self   = shift;
  my $outPkt = AttenSwitch::Packet->new( command => AttenSwitch::COMMAND->AMBIENTTHP, payload => "" );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  my $pl = $rxPacket->payload;
  my ( $t, $h, $p ) = unpack( "lll", $pl );
  return ( [ $t / 100.0, $h / 10.0, $p / 100.0 ] );
}

=over 4

=item B<< $return = $attenswitch->getAirlinePT() >> 

Reads ambient air temp, pressure and humidity. Returns [PressurePSI,TempC]


=back


=cut

sub getAirlinePT {
  my $self   = shift;
  my $outPkt = AttenSwitch::Packet->new( command => AttenSwitch::COMMAND->AIRPRESSTEMP, payload => "" );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);

  #$rxPacket->dump;
  my $pl = $rxPacket->payload;
  my ( $t, $p ) = unpack( "ll", $pl );
  return ( [ $p / 100.0, $t / 100.0 ] );
}

=over 4

=item B<< $return = $attenswitch->readEE($addr,$nbytes) >> 

Returns a string of bytes.

=back


=cut

sub readEE {
  my $self   = shift;
  my $addr   = shift;
  my $nbytes = shift;
  my $ret    = "";
  my $k      = 0;
  my $outPkt;
  for ( $k = 0 ; $k < $nbytes ; $k++ ) {
    $outPkt = AttenSwitch::Packet->new(
      command => AttenSwitch::COMMAND->READEE,
      payload => pack( "v", $addr + $k )
    );
    my ( $res, $rxPacket ) = $self->send_packet($outPkt);
    my $x = substr( $rxPacket->payload, 2, 1 );
    $ret .= $x;
  }
  return ($ret);
}

=over 4

=item B<< $attenswitch->writeEE($addr,$val) >> 

Writes $val to $addr in EEprom ... $val can be a string of more than one byte.
Be careful, the EEprom is where the device stores its identifying info.

=back

=cut

sub writeEE {
  my $self = shift;
  my $addr = shift;
  my $val  = shift;    # string of bytes
  my $k    = 0;
  my $outPkt;
  for ( $k = 0 ; $k < length($val) ; $k++ ) {
    $outPkt = AttenSwitch::Packet->new(
      command => AttenSwitch::COMMAND->WRITEEE,
      payload => pack( "v", $addr + $k ) . substr( $val, $k, 1 )
    );
    my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  }
}

=over 4

=item B<< $attenswitch->eraseAllEE() >> 

Bulk erase the EEprom. Dangerous.

=back

=cut

sub eraseAllEE {
  my $self   = shift;
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->ERASEALL,
    payload => ""
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  return ($res);
}

=over 4

=item B<< $info = $attenswitch->identify() >> 

Ask the device to self-identify. Returns an AttenSwitch::ProdInfo object.

=back

=cut

sub identify {
  my $self   = shift;
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->ID,
    payload => ""
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  my $info = AttenSwitch::ProdInfo->new();
  $info->fromIDPacket($rxPacket);
  return ($info);
}

=over 4

=item B<< $attenswitch->blink($on) >>

Ask the device to rapidly blink it's red led for easy identification.
$on should be 1 for blink on, 0 for blink off

=back

=cut

sub blink {
  my $self   = shift;
  my $on     = shift || 0;
  my $outPkt = AttenSwitch::Packet->new(
    command => AttenSwitch::COMMAND->BLINK,
    payload => pack( "C", $on )
  );
  my ( $res, $rxPacket ) = $self->send_packet($outPkt);
  return ($res);
}

# EEProm Memory Map
# 0 - Magic. 0xAA if it's not there, don't read eeprom
# 1,2 - VID little endian
# 3,4 - PID little endian
# 5,6 - Mfg pointer. Address of Mfg string. If ptr or length are zero, don't read.
# 7 - Mfg length
# 8,9 - Product string pointer (LE).
# A - Product string length
# B,C - Serial number pointer (LE).
# D  - Serial number length
# E  - S1 is pulse high (boolean)
# F  - S2 is pulse high (boolean)
# 10,11 - Extra string ptr.
# 12 - Extra string length.
#
# Strings should start at 0x30 to leave room.

=over 4

=item B<< $attenswitch->eeMagic($value) >>

Read/Write the magic value from EEprom. If called without args, read. Else write.
Magic is one byte, 0xAA to indicate EEprom is valid.

=back

=cut

sub eeMagic {
  my $self = shift;
  my $val  = shift;         #number
  if ( defined($val) ) {    # Writing
    $val = $val + 0;
    $val = $val & 0xff;
    $self->writeEE( 0, pack( "C", $val ) );
  } else {                  #reading
    $val = unpack( "C", $self->readEE( 0, 1 ) );
  }
  return ( $val + 0 );
}

=over 4

=item B<< ($vid,$pid) = $attenswitch->eeVidPid($vid,$pid) >>

Read/Write the VID and PID values from EEprom. If called without PID, read. Else write.
VID will default to our default VID if undef. VID and PID are 16 bit numbers.

=back

=cut

sub eeVidPid {
  my $self = shift;
  my $vid  = shift || AttenSwitch->validVidPids()->[0]->[0];
  my $pid  = shift;
  if ( defined($pid) ) {    # Writing
    $vid &= 0xffff;
    $pid &= 0xffff;
    $self->writeEE( 1, pack( "vv", $vid, $pid ) );
  } else {                  #Reading
    ( $vid, $pid ) = unpack( "vv", $self->readEE( 1, 4 ) );
  }
  return ( $vid, $pid );
}

=over 4

=item B<< $stringArrayref = $attenswitch->readEEStrings() >>

Read the EEprom strings and return in an array reference:
$stringArrayref->[0] = Manufacturer string,
$stringArrayref->[1] = Product string,
$stringArrayref->[2] = Serial number string,
$stringArrayref->[3] = Extra string

=back

=cut

sub readEEStrings {
  my $self    = shift;
  my @strings = ( "", "", "", "" );
  my ( $mfgP, $mfgL )     = unpack( "vC", $self->readEE( 5, 3 ) );
  my ( $prdP, $prdL )     = unpack( "vC", $self->readEE( 8, 3 ) );
  my ( $serP, $serL )     = unpack( "vC", $self->readEE( 0xb, 3 ) );
  my ( $extraP, $extraL ) = unpack( "vC", $self->readEE( 0x10, 3 ) );
  if ( $self->validStr( $mfgP, $mfgL ) ) {
    $strings[0] = $self->readEE( $mfgP, $mfgL );
  }
  if ( $self->validStr( $prdP, $prdL ) ) {
    $strings[1] = $self->readEE( $prdP, $prdL );
  }
  if ( $self->validStr( $serP, $serL ) ) {
    $strings[2] = $self->readEE( $serP, $serL );
  }
  if ( $self->validStr( $extraP, $extraL ) ) {
    $strings[3] = $self->readEE( $extraP, $extraL );
  }
  return ( \@strings );
}

sub validStr {
  my $self = shift;
  my $ptr  = shift;
  my $len  = shift;
  return (0) if ( $ptr < 0x20 );
  return (0) if ( $len == 0 );
  return (0) if ( ( $ptr + $len ) >= $self->eepromSize );
  return (1);
}

=over 4

=item B<< $attenswitch->writeEEStrings($stringArrayref) >>

Write the EEprom strings:
$stringArrayref->[0] = Manufacturer string,
$stringArrayref->[1] = Product string,
$stringArrayref->[2] = Serial number string,
$stringArrayref->[3] = Extra string

=back

=cut

sub writeEEStrings {
  my $self      = shift;
  my $stringRef = shift;
  $stringRef->[0] = "" if ( !defined( $stringRef->[0] ) );
  $stringRef->[1] = "" if ( !defined( $stringRef->[1] ) );
  $stringRef->[2] = "" if ( !defined( $stringRef->[2] ) );
  $stringRef->[3] = "" if ( !defined( $stringRef->[3] ) );
  my $addr = 0x30;

  #Manufacturer string
  if ( length( $stringRef->[0] ) ) {
    $self->writeEE( 0x5,   pack( "vC", $addr, length( $stringRef->[0] ) ) );
    $self->writeEE( $addr, $stringRef->[0] );
    $addr += length( $stringRef->[0] );
  } else {
    $self->writeEE( 0x5, pack( "vC", 0, 0 ) );
  }

  #Product string
  if ( length( $stringRef->[1] ) ) {
    $self->writeEE( 0x8,   pack( "vC", $addr, length( $stringRef->[1] ) ) );
    $self->writeEE( $addr, $stringRef->[1] );
    $addr += length( $stringRef->[1] );
  } else {
    $self->writeEE( 0x8, pack( "vC", 0, 0 ) );
  }

  #Serial string
  if ( length( $stringRef->[2] ) ) {
    $self->writeEE( 0xb,   pack( "vC", $addr, length( $stringRef->[2] ) ) );
    $self->writeEE( $addr, $stringRef->[2] );
    $addr += length( $stringRef->[2] );
  } else {
    $self->writeEE( 0xb, pack( "vC", 0, 0 ) );
  }

  #Extra string
  if ( length( $stringRef->[3] ) ) {
    $self->writeEE( 0x10,  pack( "vC", $addr, length( $stringRef->[3] ) ) );
    $self->writeEE( $addr, $stringRef->[3] );
    $addr += length( $stringRef->[3] );
  } else {
    $self->writeEE( 0x10, pack( "vC", 0, 0 ) );
  }
}

=over 4

=item B<< ($s1pol,$s2pol) = $attenswitch->eePolarity($s1pol,$s2pol) >>

Read/Write the S1 & S2 polarity values from EEprom. If called without S1 polarity, read. Else write.
$s1pol and $s2pol are booleans. 1 = pulse high, 0 = pulse low.

=back

=cut

sub eePolarity {
  my $self  = shift;
  my $s1pol = shift;
  my $s2pol = shift || $s1pol;
  if ( defined($s1pol) ) {    #Writing
    $self->writeEE( 0xe, pack( "CC", ( $s1pol != 0 ), ( $s2pol != 0 ) ) );
  } else {
    ( $s1pol, $s2pol ) = unpack( "CC", $self->readEE( 0xe, 2 ) );
  }
  return ( $s1pol, $s2pol );
}
__PACKAGE__->meta->make_immutable;
1;

package AttenSwitch::Packet;
use Moose;
use namespace::autoclean;
has proto_version => (
  is      => 'rw',
  isa     => 'Int',
  default => 1
);
has command => (
  is        => 'rw',
  isa       => "AttenSwitch::COMMAND",
  predicate => 'has_command'
);
has payload => (
  is        => 'rw',
  isa       => 'Str',
  predicate => 'has_payload'
);
has packet => (
  is  => 'rw',
  isa => 'Str'
);

#Called right after object construction so we can say:
# $obj=AttenSwitch::Packet->new(command=>$command,payload=>$payload);
sub BUILD {
  my $self = shift;
  $self->make() if ( $self->has_command() && $self->has_payload() );
}

sub make {
  my $self    = shift;
  my $command = shift;    #AttenSwitch::COMMAND
  my $payload = shift;    #String of bytes
  if ( defined($command)
    && ref($command)
    && $command->isa("AttenSwitch::COMMAND") )
  {
    $self->command($command);
  }
  if ( defined($payload) ) {
    $self->payload($payload);
  }
  if ( $self->has_command() && $self->has_payload() ) {
    $self->packet( pack( "CvC", 1, length( $self->payload ) + 6, $self->command->ordinal ) );
    $self->packet( $self->packet . pack( "v", $self->cksum_simple( $self->payload ) ) );
    $self->packet( $self->packet . $self->payload );
  }
}

sub from_bytes {
  my $self   = shift;
  my $packet = shift;
  if ( defined($packet) ) {
    $self->packet($packet);
  }
  my $ver = unpack( 'C', substr( $self->packet, 0, 1 ) );
  my $len = unpack( 'v', substr( $self->packet, 1, 2 ) );
  my $cmd = unpack( 'C', substr( $self->packet, 3, 1 ) );
  my $sum = unpack( 'v', substr( $self->packet, 4, 2 ) );
  $self->payload( substr( $self->packet, 6 ) );
  $self->command( AttenSwitch::COMMAND->from_ordinal($cmd) );
}

sub cksum_simple {
  my $self    = shift;
  my $payload = shift;
  my $sum     = 0;
  for my $ch ( unpack( 'C*', $payload ) ) {
    $sum += $ch;
    $sum &= 0xffff;
  }
  return ($sum);
}

sub dump {
  my $self  = shift;
  my $pkt   = $self->payload;
  my $ascii = "";
  my $ver   = unpack( 'C', substr( $self->packet, 0, 1 ) );
  my $len   = unpack( 'v', substr( $self->packet, 1, 2 ) );
  my $sum   = unpack( 'v', substr( $self->packet, 4, 2 ) );
  printf( "Ver: %d\n",   $ver );
  printf( "Len: %d\n",   $len );
  printf( "Cmd: %s\n",   $self->command->name );
  printf( "Sum: 0x%x\n", $sum );
  printf("Payload:\n");
  printf( "%04x - ", 0 );
  my $j = 0;

  for ( $j = 0 ; $j < length($pkt) ; $j++ ) {
    my $val = unpack( "C", substr( $pkt, $j, 1 ) );
    if ( $j && !( $j % 16 ) ) {
      printf("   $ascii");
      $ascii = "";
      printf( "\n%04x - ", $j );
    }
    if ( ( $val < 0x20 ) || ( $val > 0x7E ) ) {
      $ascii .= '.';
    } else {
      $ascii .= chr($val);
    }
    printf( "%02x ", $val );
  }
  my $adj = 16 - ( $j % 16 );
  print '   ' x $adj, "   ", $ascii, "\n";
}
__PACKAGE__->meta->make_immutable;
1;

package AttenSwitch::ProdInfo;
use Moose;
use namespace::autoclean;
has 'productID' => (
  is  => 'rw',
  isa => 'AttenSwitch::PRODUCTID'
);
has 'protocolVersion' => (
  is  => 'rw',
  isa => 'Int'
);
has 'fwRevMajor' => (
  is  => 'rw',
  isa => 'Int'
);
has 'fwRevMinor' => (
  is  => 'rw',
  isa => 'Int'
);
has 'fwRevBuild' => (
  is  => 'rw',
  isa => 'Int'
);
has 'fwSHA1' => (
  is  => 'rw',
  isa => 'Str'
);
has 'fwBldInfo' => (
  is  => 'rw',
  isa => 'Str'
);
has 'SN' => (
  is  => 'rw',
  isa => 'Str'
);

sub fromIDPacket {
  my $self   = shift;
  my $packet = shift;
  my $pl     = $packet->payload;
  my ( $prod, $proto, $fwMajor, $fwMinor, $fwBuild, $bldSha ) = unpack( "CCCCvC/a", $pl );
  $self->productID( AttenSwitch::PRODUCTID->from_ordinal($prod) );
  $self->protocolVersion($proto);
  $self->fwRevMajor($fwMajor);
  $self->fwRevMinor($fwMinor);
  $self->fwRevBuild($fwBuild);
  $self->fwSHA1($bldSha);
}
__PACKAGE__->meta->make_immutable;
1;
#
# BEGIN ENUMERATION CLASSES
#
package AttenSwitch::COMMAND;
use Class::Enum qw(ACK NAK RESET ID ECHO SSN DIAG SP8T
  AUXOUT AUXIN ATT LIGHT NOTIFY READEE
  WRITEEE SPDT ERASEALL BLINK AMBIENTTHP AIRPRESSTEMP
  KS8769M
);
1;

package AttenSwitch::ATTEN;
use Class::Enum qw(ATT_0DB ATT_10DB ATT_20DB ATT_30DB ATT_40DB
  ATT_50DB ATT_60DB ATT_70DB);
1;

package AttenSwitch::VERSION;
use Class::Enum qw(REV_UNKNOWN REVA );
1;

package AttenSwitch::SPDTSETTING;
use Class::Enum qw(J1SEL J2SEL);
1;

package AttenSwitch::SPDTSEL;
use Class::Enum qw(SW1 SW2);
1;

package AttenSwitch::SP8TSETTING;
use Class::Enum qw(J1 J2 J3 J4 J5 J6 J7 J8);
our @fromOrdinal = ( undef,  AttenSwitch::SP8TSETTING::J1, AttenSwitch::SP8TSETTING::J2, AttenSwitch::SP8TSETTING::J3, AttenSwitch::SP8TSETTING::J4, AttenSwitch::SP8TSETTING::J5, AttenSwitch::SP8TSETTING::J6, AttenSwitch::SP8TSETTING::J7, AttenSwitch::SP8TSETTING::J8 );
1;

package AttenSwitch::PRODUCTID;
use Class::Enum (
  PROD_UNKNOWN      => { ordinal => 0xff },
  PROD_STACKLIGHT   => { ordinal => 1 },
  PROD_MAPLEOLT     => { ordinal => 2 },
  PROD_ATTEN70      => { ordinal => 3 },
  PROD_DUALSPDT     => { ordinal => 4 },
  PROD_PRESSURESENS => { ordinal => 5 },
  PROD_KS8769M      => { ordinal => 6 },
);
1;
