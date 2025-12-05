-- 99bottles.trs, program-table-fied
program = {
  'INT N 98',
  'INT ONE 1',
  'INT C 0',
  'LIT T "Take one down, pass it around,"',
    
  'WHL N',
  'MOV C N',
  'ADD C ONE',
  'LIT A ""',
  'CCT A C',
  'LIT B " bottles of beer on the wall,"',
  'CCT A B',
  'PRN A',

  'LIT A ""',
  'CCT A C',
  'LIT B " bottles of beer!"',
  'CCT A B',
  'PRN A',

  'PRN T',

  'SUB N ONE',

  'JEZ N 28',

  'LIT A ""',
  'CCT A C',
  'LIT B " bottles of beer on the wall! \n "',
  'CCT A B',
  'PRN A',

  'JMP 3',

  'ENW',

  'LIT A "1 bottle of beer on the wall! \n "',
  'PRN A',

  'LIT A "1 bottle of beer on the wall,"',
  'PRN A',

  'LIT A "1 bottle of beer!"',
  'PRN A',

  'PRN T',
  
  'LIT A "No more bottles of beer on the wall!"',
  'PRN A'
}
