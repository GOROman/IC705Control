#!/usr/bin/ruby

require 'rubygems'
gem 'serialport','>=1.0.4'
require 'serialport'

TTY="/dev/tty.usbmodem14424201"

IC705_ADDR  = 0xA4

MODE_USB    = 0x01
MODE_CW     = 0x03
MODE_FM     = 0x05

class ICOM_CIV
    def initialize(addr = IC705_ADDR)
        @com = SerialPort.new(TTY, 19200, 8, 1, 0) 
        @com.read_timeout = 10

        @addr = addr
        @pkt  = []
    end

    def close
        @com.close
    end

    def preamble()
        @pkt = [0xFE, 0xFE, @addr, 0x01]
    end

    def postamble()
        @pkt << 0xFD

        print ">> "
        @pkt.each {|b|
            printf("%02X ", b )
        }
        puts

        @com.write @pkt.pack("C*")
        @com.flush
    end

    def send_byte( cmd, sub, data = [] )
        self.preamble
        @pkt << cmd
        @pkt << sub
        data.each do |n|
            @pkt << n 
        end
        self.postamble
    end

    def send_word( cmd, sub, data = [] )
        self.preamble   
        @pkt << cmd
        @pkt << sub
        data.each do |n| 
            setData( n )
        end
        self.postamble
    end

    def preset( preset ) 
        self.preamble
        @pkt << 0x06
        self.postamble
    end

    def split( param )
        puts "SPLIT"
        send_byte( 0x0F, param )
    end

    def smeter
        send_byte( 0x15, 0x02 )
         
        p @com.read 9
    end

    def keyer( a ) 
        puts "KEYER"
        self.preamble
        @pkt << 0x1a
        @pkt << 0x05
        setData(255)
        @pkt << a
        self.postamble
    end

    def keyer_speed( a ) 
        puts "KEYER SPEED(#{a})"
        send_word( 0x14, 0x0C, [a] )
    end

    def keyer_freq( a ) 
        puts "KEYER FREQ(#{a})"
        send_word( 0x14, 0x09, [a] )
    end

    def keyer_tone_level( a ) 
        puts "KEYER TONE LEVEL(#{a})"
        send_word( 0x1A, 0x05, [249, a] )
    end

    def keyer_reverse( a ) 
        puts "KEYER REVERSE(#{a})"
        self.preamble
        @pkt << 0x1a
        @pkt << 0x05
        setData(254)
        @pkt << a
        self.postamble
    end

    def af( a )
        puts "AF GAIN(#{a})"
        send_word( 0x14, 0x01, [a] )
    end

    def setData( param )
        a = sprintf( "%04d", param )
        @pkt << a[0..1].hex
        @pkt << a[2..3].hex
    end

    def mode( mode, data = 0, filter = 1 )
        send_byte( 0x26, 0x00, [mode, data, filter])
    end

    def sql( level )
        send_word( 0x14, 0x03, [level] )
    end

    def usb_af_output_level( level )
        send_word( 0x1A, 0x05, [109, 0] )   # 00=AF / 01=IF
        send_word( 0x1A, 0x05, [110, level] )
    end

    def usb_input_mod_level( level )
        puts "USB INPUT MOD LEVEL(#{level})"
        send_word( 0x1A, 0x05, [116, level] )
    end

    def preset_ft8
        mode    MODE_USBD, 1, 1
        sql     0
        usb_af_output_level 64                 # ここを 30dBになるように調整する
        usb_input_mod_level 128 # (0.1 * 256).to_i
        # FIL1
        # FILTER BW: 3.0K
        # FILTER TYPE: SHARP
        # COMP:OFF
        # SSB TBW:WIDE
        # SSB WIDTH:100-2900    
    end
end

icom = ICOM_CIV.new( IC705_ADDR )

icom.mode MODE_FM, 0, 1
icom.smeter

icom.mode MODE_CW, 0, 1
icom.split 0
icom.keyer 2
icom.keyer_freq(128)
icom.keyer_reverse(0)
icom.keyer_speed(64)
icom.keyer_tone_level(255)

#icom.preset_ft8 #FT8
icom.close

