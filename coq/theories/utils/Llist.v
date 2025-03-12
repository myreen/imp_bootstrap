CoInductive llist {A : Type} : Type :=
| lnil : llist
| lcons : A -> llist -> llist.
Arguments llist : clear implicits.

Definition ltail {A : Type} (l : llist A) : llist A :=
  match l with
  | lnil => lnil
  | lcons _ tl => tl
  end.
