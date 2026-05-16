#pragma once

#include <QObject>
#include <QVariantMap>
#include <QString>

// Tiny helper exposing IANA-aware time queries to QML/JS.
// Qt 5.12's V4 engine ignores the `timeZone` option of `Date.toLocaleString`
// (limited Intl support), so the JS-side `get_current_time` tool silently
// falls back to the system timezone. We delegate to QTimeZone here instead.
class TimeUtil : public QObject {
    Q_OBJECT
public:
    explicit TimeUtil(QObject *parent = nullptr);

    // Returns { iso, unix_ms, timezone, local, utc_offset_minutes } on success
    // or { error: "..." } if the IANA timezone id is not recognized.
    Q_INVOKABLE QVariantMap nowInTimezone(const QString &tz);
};
