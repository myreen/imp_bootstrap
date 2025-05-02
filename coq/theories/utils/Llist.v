CoInductive llist {A : Type} : Type :=
| Lnil : llist
| Lcons : A -> llist -> llist.
Arguments llist : clear implicits.

Definition ltail {A : Type} (l : llist A) : llist A :=
  match l with
  | Lnil => Lnil
  | Lcons _ tl => tl
  end.
