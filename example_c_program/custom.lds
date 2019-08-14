
ENTRY(main)

SECTIONS
{
   . = 0x00000;
   .text : { *(.text) }
   . = 0x01000;
   .data : { *(.data) }
}
