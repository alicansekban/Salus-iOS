// Every key `:feature:smoking` owns so far, with both translations, copied from the XML on branch
// `feature/m17-smoking-cessation` (`feature/smoking/src/main/res/values{,-en}/strings.xml`). A new
// key there means a new row here, in the same commit — that is the whole job of this table.
//
// Its own type, not rows inside the suite: it is data, not a test, and 64 rows inside the suite put
// its body past SwiftLint's 300-line `type_body_length`.

struct SmokingStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}

enum SmokingStringTable {
    static let samples: [SmokingStringSample] = head + SmokingStringTableTail.samples

    private static let head: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_title",
            turkish: "Sigara",
            english: "Smoking"
        ),
        SmokingStringSample(
            key: "smoking_error_generic",
            turkish: "Kaydedilemedi, lütfen tekrar dene.",
            english: "Couldn't save. Please try again."
        ),
        SmokingStringSample(
            key: "smoking_setup_title",
            turkish: "Sigara Kurulumu",
            english: "Smoking setup"
        ),
        SmokingStringSample(
            key: "smoking_setup_step_of",
            turkish: "ADIM %1$lld / %2$lld",
            english: "STEP %1$lld / %2$lld"
        ),
        SmokingStringSample(
            key: "smoking_setup_continue",
            turkish: "Devam",
            english: "Continue"
        ),
        SmokingStringSample(
            key: "smoking_setup_start",
            turkish: "Başla",
            english: "Start"
        ),
        SmokingStringSample(
            key: "smoking_setup_error_future_date",
            turkish: "Bırakma zamanı şu andan ileride olamaz.",
            english: "The quit time can't be in the future."
        ),
        SmokingStringSample(
            key: "smoking_setup_error_invalid",
            turkish: "Bilgilerini kontrol edip tekrar dene.",
            english: "Check your details and try again."
        ),
        SmokingStringSample(
            key: "smoking_setup_mode_title",
            turkish: "Hedefin ne?",
            english: "What's your goal?"
        ),
        SmokingStringSample(
            key: "smoking_setup_mode_subtitle",
            turkish: "Sana en uygun takip şeklini belirleyelim. İstediğin zaman değiştirebilirsin.",
            english: "Let's set up the kind of tracking that suits you. You can change it any time."
        ),
        SmokingStringSample(
            key: "smoking_setup_mode_quit",
            turkish: "Bıraktım / bırakıyorum",
            english: "I quit / I'm quitting"
        ),
        SmokingStringSample(
            key: "smoking_setup_mode_quit_desc",
            turkish: "Sayaç başlasın, kazandıklarını gör",
            english: "Start the counter and see what you gain"
        ),
        SmokingStringSample(
            key: "smoking_setup_mode_reduce",
            turkish: "Azaltmak istiyorum",
            english: "I want to cut down"
        ),
        SmokingStringSample(
            key: "smoking_setup_mode_reduce_desc",
            turkish: "Günlük kaydet, adım adım düşür",
            english: "Log each day and bring it down step by step"
        ),
        SmokingStringSample(
            key: "smoking_setup_privacy",
            turkish: "Sigara bilgilerin yalnızca cihazında saklanır.",
            english: "Your smoking details are stored only on your device."
        ),
        SmokingStringSample(
            key: "smoking_setup_product_title",
            turkish: "Ne kullanıyorsun?",
            english: "What do you use?"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_subtitle",
            turkish: "Tüketimini ve harcama hesaplarını doğru yapabilmemiz için ürün tipini seç.",
            english: "Pick the product type so we can work out your use and spending accurately."
        ),
        SmokingStringSample(
            key: "smoking_setup_product_cigarette",
            turkish: "Sigara",
            english: "Cigarettes"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_cigarette_desc",
            turkish: "Standart paket",
            english: "Standard pack"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_rolled",
            turkish: "Sarma tütün",
            english: "Rolled tobacco"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_rolled_desc",
            turkish: "Tütün & tabaka",
            english: "Tobacco & papers"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_heated",
            turkish: "Isıtılmış tütün",
            english: "Heated tobacco"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_heated_desc",
            turkish: "IQOS vb. cihazlar",
            english: "IQOS and similar devices"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_vape",
            turkish: "Elektronik sigara",
            english: "E-cigarette"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_vape_desc",
            turkish: "Likit / pod mod",
            english: "Liquid / pod device"
        ),
        SmokingStringSample(
            key: "smoking_setup_product_helper",
            turkish: "Birden fazla kullanıyorsan en sık tükettiğini seç.",
            english: "If you use more than one, pick the one you use most."
        ),
        SmokingStringSample(
            key: "smoking_setup_amount_title",
            turkish: "Ne kadar ve kaça?",
            english: "How much, and at what price?"
        ),
        SmokingStringSample(
            key: "smoking_setup_amount_subtitle",
            turkish: "Mevcut alışkanlığını belirle, ilerlemeni ve tasarrufunu birlikte takip edelim.",
            english: "Tell us about your current habit so we can track your progress and your savings together."
        ),
        SmokingStringSample(
            key: "smoking_setup_amount_subtitle_vape",
            turkish: "Elektronik sigara için likit ve kartuş giderlerini haftalık olarak tahmin edelim.",
            english: "Let's estimate your e-cigarette liquid and pod costs by the week."
        ),
        SmokingStringSample(
            key: "smoking_setup_units_per_day",
            turkish: "GÜNDE KAÇ ADET?",
            english: "HOW MANY PER DAY?"
        ),
        SmokingStringSample(
            key: "smoking_setup_units_per_day_unit",
            turkish: "adet / gün",
            english: "per day"
        ),
        SmokingStringSample(
            key: "smoking_setup_pack_price",
            turkish: "PAKET FİYATI",
            english: "PACK PRICE"
        ),
        SmokingStringSample(
            key: "smoking_setup_pouch_price",
            turkish: "TÜTÜN PAKETİ FİYATI",
            english: "TOBACCO POUCH PRICE"
        ),
        SmokingStringSample(
            key: "smoking_setup_units_per_pack",
            turkish: "PAKETTE KAÇ ADET?",
            english: "HOW MANY PER PACK?"
        ),
        SmokingStringSample(
            key: "smoking_setup_units_per_pouch",
            turkish: "PAKETTEN KAÇ SİGARA ÇIKIYOR?",
            english: "CIGARETTES PER POUCH?"
        ),
        SmokingStringSample(
            key: "smoking_setup_units_per_pack_unit",
            turkish: "adet / paket",
            english: "per pack"
        ),
        SmokingStringSample(
            key: "smoking_setup_currency",
            turkish: "PARA BİRİMİ",
            english: "CURRENCY"
        ),
        SmokingStringSample(
            key: "smoking_setup_weekly_spend",
            turkish: "HAFTALIK HARCAMAN",
            english: "YOUR WEEKLY SPEND"
        ),
        SmokingStringSample(
            key: "smoking_setup_vape_selected",
            turkish: "Elektronik sigara seçili",
            english: "E-cigarette selected"
        ),
        SmokingStringSample(
            key: "smoking_setup_change_product",
            turkish: "Değiştir",
            english: "Change"
        ),
        SmokingStringSample(
            key: "smoking_setup_quick_add_label",
            turkish: "Hızlı ekle:",
            english: "Quick add:"
        ),
        SmokingStringSample(
            key: "smoking_setup_quick_add",
            turkish: "+%1$@%2$lld",
            english: "+%1$@%2$lld"
        ),
        SmokingStringSample(
            key: "smoking_setup_summary_daily",
            turkish: "Günde yaklaşık %1$@ · yılda %2$@",
            english: "About %1$@ a day · %2$@ a year"
        ),
        SmokingStringSample(
            key: "smoking_setup_summary_weekly",
            turkish: "Haftada yaklaşık %1$@ · yılda %2$@",
            english: "About %1$@ a week · %2$@ a year"
        ),
        SmokingStringSample(
            key: "smoking_setup_summary_quit",
            turkish: "Bıraktığında bu miktar cebinde kalır.",
            english: "This is what stays in your pocket once you quit."
        ),
        SmokingStringSample(
            key: "smoking_setup_summary_reduce",
            turkish: "Azalttıkça bu miktarın bir kısmı cebinde kalır.",
            english: "As you cut down, part of this amount stays in your pocket."
        ),
        SmokingStringSample(
            key: "smoking_setup_quit_title",
            turkish: "Bırakma Yolculuğun",
            english: "Your quit journey"
        ),
        SmokingStringSample(
            key: "smoking_setup_quit_subtitle",
            turkish: "Sayacını başlatmak ve hedefini netleştirmek için son bir adım.",
            english: "One last step to start your counter and set your goal."
        ),
        SmokingStringSample(
            key: "smoking_setup_quit_when",
            turkish: "NE ZAMAN BIRAKTIN?",
            english: "WHEN DID YOU QUIT?"
        ),
        SmokingStringSample(
            key: "smoking_setup_quit_now",
            turkish: "Şimdi bıraktım",
            english: "I quit just now"
        ),
        SmokingStringSample(
            key: "smoking_setup_quit_today",
            turkish: "Bugün, %1$@",
            english: "Today, %1$@"
        ),
        SmokingStringSample(
            key: "smoking_setup_quit_edit",
            turkish: "Tarih ve saati düzenle",
            english: "Edit date and time"
        ),
        SmokingStringSample(
            key: "smoking_setup_reason_label",
            turkish: "NEDEN BIRAKIYORSUN? (İSTEĞE BAĞLI)",
            english: "WHY ARE YOU QUITTING? (OPTIONAL)"
        ),
        SmokingStringSample(
            key: "smoking_setup_reason_placeholder",
            turkish: "Kızım için, sağlığım için, daha rahat nefes almak için…",
            english: "For my daughter, for my health, to breathe easier…"
        ),
        SmokingStringSample(
            key: "smoking_setup_reason_hint",
            turkish: "Zor anlarda sana bunu hatırlatacağız.",
            english: "We'll remind you of this in hard moments."
        )
    ]
}

/// The second half of the table, split off only to keep each enum under the 300-line
/// `type_body_length`.
enum SmokingStringTableTail {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_setup_reduce_title",
            turkish: "Günlük hedefini belirle",
            english: "Set your daily goal"
        ),
        SmokingStringSample(
            key: "smoking_setup_reduce_subtitle",
            turkish: "Adım adım azaltmak için, seni zorlamayan ilk gün limitini seç.",
            english: "To cut down step by step, pick a first daily limit that doesn't strain you."
        ),
        SmokingStringSample(
            key: "smoking_setup_daily_limit",
            turkish: "GÜNLÜK LİMİT",
            english: "DAILY LIMIT"
        ),
        SmokingStringSample(
            key: "smoking_setup_daily_limit_unit",
            turkish: "adet / gün",
            english: "per day"
        ),
        SmokingStringSample(
            key: "smoking_setup_limit_suggestion",
            turkish: "Öneri: şu anki miktarının %%80'i (Mevcut: %1$lld adet)",
            english: "Suggestion: 80%% of your current amount (currently %1$lld)"
        ),
        SmokingStringSample(
            key: "smoking_quit_sheet_title",
            turkish: "Ne zaman bıraktın?",
            english: "When did you quit?"
        ),
        SmokingStringSample(
            key: "smoking_quit_sheet_time",
            turkish: "Saat",
            english: "Time"
        ),
        SmokingStringSample(
            key: "smoking_quit_sheet_future",
            turkish: "Bırakma zamanı şu andan ileride olamaz.",
            english: "The quit time can't be in the future."
        ),
        SmokingStringSample(
            key: "smoking_quit_sheet_time_dialog",
            turkish: "Saati seç",
            english: "Pick the time"
        )
    ]
}
