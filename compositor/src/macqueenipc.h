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
    bool activateWorkspace(const QString &id);
    QString createWorkspace(uint position, const QString &name);
    bool removeWorkspace(const QString &id);
    bool renameWorkspace(const QString &id, const QString &name);
    bool activateWindow(const QString &id);
    bool closeWindow(const QString &id);
    bool setWindowMinimized(const QString &id, bool minimized);
    bool setWindowFullscreen(const QString &id, bool fullscreen);
    bool moveWindowToWorkspace(const QString &windowId, const QString &workspaceId);

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
