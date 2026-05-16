#include "timeutil.h"

#include <QDateTime>
#include <QTimeZone>
#include <QLocale>

TimeUtil::TimeUtil(QObject *parent) : QObject(parent) {}

QVariantMap TimeUtil::nowInTimezone(const QString &tz) {
    QVariantMap out;
    const QString tzId = tz.isEmpty() ? QStringLiteral("UTC") : tz;

    QTimeZone zone(tzId.toUtf8());
    if (!zone.isValid()) {
        out["error"] = QStringLiteral("Invalid timezone: %1").arg(tzId);
        return out;
    }

    const QDateTime nowUtc = QDateTime::currentDateTimeUtc();
    const QDateTime nowZoned = nowUtc.toTimeZone(zone);

    out["iso"] = nowUtc.toString(Qt::ISODate);
    out["unix_ms"] = nowUtc.toMSecsSinceEpoch();
    out["timezone"] = tzId;
    out["local"] = QLocale::c().toString(nowZoned, QStringLiteral("yyyy-MM-dd HH:mm:ss"))
                   + QStringLiteral(" ") + zone.abbreviation(nowUtc);
    out["utc_offset_minutes"] = zone.offsetFromUtc(nowUtc) / 60;
    return out;
}
