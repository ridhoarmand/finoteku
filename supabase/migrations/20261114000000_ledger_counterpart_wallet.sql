-- ledger_entries: dompet lawan transfer di tiap baris, supaya list tetap tahu kedua dompet
-- walau difilter per dompet atau dipotong. Kolom baru di akhir: aman untuk select('*').

CREATE OR REPLACE VIEW "public"."ledger_entries" WITH ("security_invoker"='on') AS
 SELECT "t"."id" AS "entry_id",
    "t"."user_id",
    "t"."wallet_id",
    "w"."name" AS "wallet_name",
    "t"."category_id",
    "c"."name" AS "category_name",
    "c"."type" AS "category_type",
    ( SELECT "pc"."name"
           FROM "public"."categories" "pc"
          WHERE ("pc"."id" = "c"."parent_id")) AS "category_parent",
    ("t"."amount" * (
        CASE "c"."type"
            WHEN 'expense'::"public"."category_type" THEN '-1'::integer
            ELSE 1
        END)::numeric) AS "signed_amount",
    "t"."amount",
    "t"."date",
    "t"."notes",
    'transaction'::"text" AS "kind",
    NULL::"uuid" AS "transfer_id",
    NULL::"uuid" AS "counterpart_wallet_id"
   FROM (("public"."transactions" "t"
     JOIN "public"."categories" "c" ON (("c"."id" = "t"."category_id")))
     LEFT JOIN "public"."wallets" "w" ON (("w"."id" = "t"."wallet_id")))
UNION ALL
 SELECT "tr"."id" AS "entry_id",
    "tr"."user_id",
    "tr"."from_wallet_id" AS "wallet_id",
    "fw"."name" AS "wallet_name",
    NULL::"uuid" AS "category_id",
    'Transfer Keluar'::"text" AS "category_name",
    NULL::"public"."category_type" AS "category_type",
    NULL::"text" AS "category_parent",
    (- "tr"."amount") AS "signed_amount",
    "tr"."amount",
    "tr"."date",
    "tr"."notes",
    'transfer_out'::"text" AS "kind",
    "tr"."id" AS "transfer_id",
    "tr"."to_wallet_id" AS "counterpart_wallet_id"
   FROM ("public"."transfers" "tr"
     LEFT JOIN "public"."wallets" "fw" ON (("fw"."id" = "tr"."from_wallet_id")))
UNION ALL
 SELECT "tr"."id" AS "entry_id",
    "tr"."user_id",
    "tr"."to_wallet_id" AS "wallet_id",
    "tw"."name" AS "wallet_name",
    NULL::"uuid" AS "category_id",
    'Transfer Masuk'::"text" AS "category_name",
    NULL::"public"."category_type" AS "category_type",
    NULL::"text" AS "category_parent",
    "tr"."amount" AS "signed_amount",
    "tr"."amount",
    "tr"."date",
    "tr"."notes",
    'transfer_in'::"text" AS "kind",
    "tr"."id" AS "transfer_id",
    "tr"."from_wallet_id" AS "counterpart_wallet_id"
   FROM ("public"."transfers" "tr"
     LEFT JOIN "public"."wallets" "tw" ON (("tw"."id" = "tr"."to_wallet_id")));
