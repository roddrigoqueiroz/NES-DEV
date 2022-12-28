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
  LDX #$40     ; same as #%0100 000 -> this disables IRQ
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
  STA $0200, x    ; move sprites offscreen
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006  ; PPUADDR  ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, decimal 32 - copying 32 bytes = 8 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

; NOTE: it's not needed to increment the VRAM address, because it does it automatically via the $2000 register
; at line 20 we stored 0 in the $2000 register, and one of its effects was telling the PPU to increment its addresses
; by 1 when writing to $2007
; see https://www.nesdev.org/wiki/PPU_registers#PPUCTRL for more information



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
              
              

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer


; ********** CONTROLLERS ***********
LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       ; tell both the controllers to latch buttons

; NES DEV solution for reading controllers
;   LDX #$01
;   STX mask
;   DEX
; ReadController:
;   LDA $4016
;   LSR A
;   ROL mask
;   BCC ReadController

; My solution for reading controllers
  LDX #$00
  STX mask        ; mask = 0
ReadController: 
  LDA $4016       ; reads player 1 input
  AND #$01        ; only look at bit 0
  ORA mask        ; make or between A and mask bit by bit
                  ; this actually includes the readen bit in the mask
                  ; in other words, if it reads 1, the mask gets a 1 at the same place
                  ; and if it reads 0, the mask gets it at the same place as well
  CPX #$07        ; compares X to 7 to dont do the bitshift in the last time of the loop
  BEQ StoreA
  ASL A           ; shifts left all A bits by one
StoreA:
  STA mask        ; updates mask
  INX
  CPX #$08
  BNE ReadController   ; branch to ReadController while X < 8
                  ; add instructions here to do something when button IS pressed (1)
  
  LDA mask
  AND #%00000001   ; checks if pressed the right arrow. If not, A = 0
  BEQ ReadRightDone

  LDX #$00
MoveMarioFront:
  LDA $0203, x    ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$01        ; A = A + 1
  STA $0203, x    ; save sprite X position
  TXA
  CLC
  ADC #$04
  TAX             ; X = X + 4
  CPX #$10        ; X = 16 (finish going trough all meta-sprites)
  BNE MoveMarioFront
ReadRightDone:        ; handling this button is done
  
  LDA mask
  AND #%00000010   ; checks if pressed the left arrow. If not, A = 0
  BEQ ReadLeftDone

  LDX #$00
MoveMarioBack:
  LDA $0203, x    ; load sprite X position
  SEC             ; make sure carry flag is set
  SBC #$01        ; A = A - 1
  STA $0203, x    ; save sprite X position
  TXA
  CLC
  ADC #$04
  TAX             ; X = X + 4
  CPX #$10        ; X = 16 (finish going trough all meta-sprites)
  BNE MoveMarioBack
ReadLeftDone:        ; handling this button is done


; at first, reading the controller input as I did may seem waste of time, due to just reading left and right
; but, if considering reading more buttons, it is important to have a system like this

  
  RTI             ; return from interrupt
 
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $2C,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$16,$37,$0C,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

sprites:
     ;vert tile attr horiz
  .db $80, $32, $00, $80   ;sprite 0
  .db $80, $33, $00, $88   ;sprite 1
  .db $88, $34, $00, $80   ;sprite 2
  .db $88, $35, $00, $88   ;sprite 3

; sprite_axis +$08 means that the next sprite is at side of the one before

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

  .zp
mask: .ds 1
