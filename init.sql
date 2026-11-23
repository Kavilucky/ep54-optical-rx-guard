-- Проверка рецептов на очковые линзы и автовозврат клиентов (эпизод 54, пример, не запускался на живом PostgreSQL).
-- Таблицы: rx_checks (проверенные бланки и решения врача), clients (карта клиента, согласие на напоминание, дата визита).
-- В базе нет ФИО, телефонов и дат рождения: клиент идентифицируется номером карты салона. Это снижает риск, но не отменяет 152-ФЗ: проверьте у юриста.

CREATE TABLE IF NOT EXISTS clients (
    card_no         text PRIMARY KEY,                    -- номер карты салона, без персональных данных
    client_chat_id  bigint,                              -- Telegram клиента: заполняется только после его согласия и после /start бота
    consent_recall  boolean NOT NULL DEFAULT false,      -- согласие на напоминание о проверке зрения
    last_visit      date,                                -- дата последней проверки зрения
    last_recall     timestamptz                          -- когда бот последний раз напоминал
);

CREATE TABLE IF NOT EXISTS rx_checks (
    id            bigserial PRIMARY KEY,
    created_at    timestamptz NOT NULL DEFAULT now(),
    card_no       text NOT NULL,
    od_sph        numeric(4,2),
    od_cyl        numeric(4,2),
    od_axis       smallint,
    os_sph        numeric(4,2),
    os_cyl        numeric(4,2),
    os_axis       smallint,
    add_pwr       numeric(3,2),
    pd            numeric(4,1),
    verdict       text NOT NULL CHECK (verdict IN ('ok', 'review', 'block')),
    reasons       jsonb NOT NULL DEFAULT '[]'::jsonb,
    status        text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'rejected')),
    decided_by    text,                                  -- Telegram id врача, нажавшего кнопку
    decided_at    timestamptz,
    -- Вторая линия защиты (ловушка 2 из ролика): шаг диоптрий 0,25 проверяет сама база, даже если ошибся парсер или сценарий.
    CONSTRAINT step_025_od_sph CHECK (od_sph * 4 = round(od_sph * 4)),
    CONSTRAINT step_025_od_cyl CHECK (od_cyl * 4 = round(od_cyl * 4)),
    CONSTRAINT step_025_os_sph CHECK (os_sph * 4 = round(os_sph * 4)),
    CONSTRAINT step_025_os_cyl CHECK (os_cyl * 4 = round(os_cyl * 4)),
    CONSTRAINT step_025_add    CHECK (add_pwr * 4 = round(add_pwr * 4)),
    CONSTRAINT axis_range      CHECK ((od_axis IS NULL OR od_axis BETWEEN 0 AND 180) AND (os_axis IS NULL OR os_axis BETWEEN 0 AND 180)),
    CONSTRAINT cyl_range       CHECK ((od_cyl IS NULL OR od_cyl BETWEEN -8 AND 8) AND (os_cyl IS NULL OR os_cyl BETWEEN -8 AND 8))
);
CREATE INDEX IF NOT EXISTS rx_checks_card_idx ON rx_checks (card_no, id DESC);

-- Пример (выдуманные значения): подтверждённый рецепт для проверки сценария на карте 1001.
INSERT INTO clients (card_no, consent_recall, last_visit) VALUES ('1001', false, current_date - interval '12 months') ON CONFLICT DO NOTHING;
INSERT INTO rx_checks (card_no, od_sph, od_cyl, od_axis, os_sph, os_cyl, os_axis, add_pwr, pd, verdict, status, decided_by, decided_at)
SELECT '1001', -2.00, -1.25, 175, -1.75, -1.00, 10, 2.25, 63, 'ok', 'confirmed', 'example', now() - interval '12 months'
WHERE NOT EXISTS (SELECT 1 FROM rx_checks WHERE card_no = '1001');
