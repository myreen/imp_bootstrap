CoInductive Llist (A : Type) : Type :=
| Lnil : Llist A
| Lcons : A -> Llist A -> Llist A.
