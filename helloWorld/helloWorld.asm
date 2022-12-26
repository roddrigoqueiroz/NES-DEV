  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

    
  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x    ;move all sprites off screen
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

; *********** PALETTES ***********
LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  
  
  LDX #$00     ; clears the X register before using it 
LoadPalettesLoop:
  LDA palette, x        ;load palette byte
  STA $2007             ;write to PPU
  INX                   ;set index to next byte
  CPX #$20            
  BNE LoadPalettesLoop  ;if x = $20, 32 bytes copied, all done


; *********** SPRITES ***********
  LDX #$00         ; initializes registers
  LDY #$00
  LDA #$47
  PHA
hello:
  LDA #$70
  STA $0200, X	   ; puts sprite in vert axis
  PLA              ; pulls A from stack (first time A = #$47)
  STA $0203, X	   ; puts sprite in horz axis
  CLC
  ADC #$0A	       ; same as #$47 + $0A (in the first loop)
  PHA
  LDA string, Y	   ; loads A with the "HELLO WORLD" string char by char
  STA $0201, X	   ; stores the string, one char at a time, in address
  LDA #$00	       ; selecting the first color pallete and not fliping
  STA $0202, X     ; stores the above data in address $0202 + X
  CLC
  TXA
  ADC #$04
  TAX              ; the above instructions add 4 to the X register, offsetting the sprite original addresses ($0200-$0203)
  INY              ; Y++, so it selects the next sprite in the sprites list
  CPY #$0B	       ; checking if Y <= 11 (end of the string)
  BNE hello
  
  LDA #%10001000   ; enable NMI, sprites from Pattern Table 1
  		   ; 3th bit is used to get the pattern table. I want patter table 1, so i put 1 in there
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 
; This loop is responsable for displaying the sprites on the screen via OAM DMA
NMI:
  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the transfer
  
  RTI        ; return from interrupt
 
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F ; background collor palletes
  .db $0F,$30,$31,$11,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C ; sprites collor palletes
string:
  .db 17, 14, 21, 21, 24, 36, 32, 24, 27, 21, 13   ; "HELLO WORLD" written in mario's nametable sprites' indexes


  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1
