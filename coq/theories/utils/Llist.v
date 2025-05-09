CoInductive llist {A : Type} : Type :=
| Lnil : llist
| Lcons : A -> llist -> llist.
Arguments llist : clear implicits.

Definition ltail {A : Type} (l : llist A) : llist A :=
  match l with
  | Lnil => Lnil
  | Lcons _ tl => tl
  end.

Fixpoint llist_of_list {A: Type} (l: list A): llist A :=
  match l with
  | nil => Lnil
  | cons x xs => Lcons x (llist_of_list xs)
  end.
