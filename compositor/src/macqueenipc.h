/*
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

namespace KWin
{

class Window;
class Workspace;

class MacqueenIpc : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.macqueen.Compositor1")

public:
    explicit MacqueenIpc(Workspace *workspace);
    ~MacqueenIpc() override;

public Q_SLOTS:
    uint protocolVersion() const;
    QString compositorVersion() const;
    QVariantMap activeWindow() const;
    QVariantList windows() const;
    QVariantList outputs() const;
    QVariantList workspaces() const;

Q_SIGNALS:
    void windowAdded(const QString &id);
    void windowRemoved(const QString &id);
    void windowChanged(const QString &id, const QStringList &fields);
    void activeWindowChanged(const QString &id);
    void outputsChanged();
    void workspacesChanged();

private:
    void watchWindow(Window *window);
    QVariantMap windowData(const Window *window) const;

    Workspace *m_workspace;
    const QString m_serviceName = QStringLiteral("org.macqueen.Compositor1");
};

} // namespace KWin
