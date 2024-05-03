# Case 1: forward move

Actual:

a b c d e f

a d b c e f  move d to before b

a x d b c e f  insert x before d

a x d b c e f z  insert z after f


CollectionDifference:

a b c d e f

a b c e f  remove d (offset 3)

a x b c e f  insert x (offset 1)

a x d b c e f  insert d (offset 2)

a x d b c e f z  insert z (offset 7)


CollectionDifferenceWithMoves:

a b c d e f

a b c D e f  **skip removal of d** (offset **3**)

a x b c D e f  insert x (offset 1)

a x D b c e f  move d from offset **4** to offset 2

a x d b c e f z  insert z (offset 7)



# Case 2: backward move

Actual:

a b c d e f

a c d e b f  move b to before f

a c g d e b f  insert g before d

a c g d e b f z  insert z after f

CollectionDifference:

a b c d e f

a c d e f  remove b (offset 1)

a c g d e f  insert g (offset **2**)

a c g d e b f  insert b (offset 5)

a c g d e b f z  insert z (offset 7)

CollectionDifferenceWithMoves:

a b c d e f

a B c d e f  **skip removal of b** (offset 1)

a B c g d e f  insert g (offset **3**)

a c g d e B f  *move* b from offset 1 to offset 5

a c g d e b f z  insert z (offset 7)

Note the destination offset will actually need to be 5+1 because of Spotify's reorder operation semantics, which, when considering both forward and backward movement of single elements, seems equivalent to:
1. make a copy of the element at index=`range_start`
2. insert the copy at index=`insert_before`
3. remove the element at index=`range_start`
This can be handled at a higher-level than the actual diffing though (e.g. in moveSideEffect, increment the destination offset **if destination offset > source offset**).
