Inductive app_list {A: Type}: Type :=
| List : list A -> app_list
| Append : app_list -> app_list -> app_list.
Arguments app_list: clear implicits.

Declare Scope app_list_scope.
Notation "xs +++ ys" := (Append xs ys) (right associativity, at level 60): app_list_scope.

Fixpoint flatten {A: Type} (xs: app_list A): list A :=
  match xs with
  | List l => l
  | Append l1 l2 => flatten l1 ++ flatten l2
  end.

Fixpoint app_list_length {A: Type} (xs: app_list A): nat :=
  match xs with
  | List l => length l
  | Append l1 l2 => app_list_length l1 + app_list_length l2
  end.
