// ============================================================================
// LAB-02 — Trazabilidad en MongoDB Community
// Archivo: scripts/comandos-mongosh.js
// Alumno: Arturo Torres Urias | Grupo: 4-3
// Motor: MongoDB 7.0.48 Community Edition (mongosh 2.14.2)
// NOTA: Las contraseñas de práctica han sido sustituidas por <REDACTED>.
// ============================================================================

// --- 6.3 Crear los usuarios y los datos (excepción de localhost) ---
use("admin");
db.createUser({ user: "admin", pwd: "<REDACTED>", roles: ["root"] });
db.auth("admin", "<REDACTED>");

use("comercial");
db.createUser({
  user: "app_ventas",
  pwd: "<REDACTED>",
  roles: [{ role: "readWrite", db: "comercial" }]
});

db.clientes.insertMany([
  { _id: 1, nombre: "Ana López", correo: "ana.lopez@example.test", telefono: "6671234567", rfc: "LOAA850315ABC", edad: 41, ciudad: "Culiacán", codigo_postal: "80000" },
  { _id: 2, nombre: "Carlos Pérez", correo: "carlos.perez@example.test", telefono: "6672345678", rfc: "PECA900720DEF", edad: 35, ciudad: "Culiacán", codigo_postal: "80100" },
  { _id: 3, nombre: "María García", correo: "maria.garcia@example.test", telefono: "6673456789", rfc: "GAMA780912GHI", edad: 47, ciudad: "Mazatlán", codigo_postal: "82000" },
  { _id: 4, nombre: "Luis Torres", correo: "luis.torres@example.test", telefono: "6674567890", rfc: "TOLU920201JKL", edad: 34, ciudad: "Los Mochis", codigo_postal: "81200" },
  { _id: 5, nombre: "Laura Sánchez", correo: "laura.sanchez@example.test", telefono: "6675678901", rfc: "SALA880525MNO", edad: 38, ciudad: "Culiacán", codigo_postal: "80200" }
]);

// --- 6.4 Función auxiliar para leer la bitácora en memoria (getLog) ---
function bitacora() {
  return db.adminCommand({ getLog: "global" }).log.map(l => JSON.parse(l));
}

// --- 7. Actividad 1 — Lo que no existe en esta edición ---
db.version();
db.adminCommand({ buildInfo: 1 }).modules;
db.serverCmdLineOpts().parsed;

// --- 8. Actividad 2 — El incidente sin perfilado ---
db.getProfilingStatus();
// (Desde terminal app_ventas: db.clientes.updateOne({ _id: 3 }, { $set: { rfc: "GAMA780912XXX" } }))
db.system.profile.countDocuments();
bitacora().filter(e => JSON.stringify(e).includes("GAMA780912XXX")).length;
bitacora().filter(e => JSON.stringify(e).includes("app-ventas-web")).map(e => ({ t: e.t, c: e.c, ctx: e.ctx, msg: e.msg }));

// --- 9. Actividad 3 — Activar el perfilador y registrar operaciones ---
db.setProfilingLevel(2);
db.getProfilingStatus();
// (Desde terminal app_ventas: find({ ciudad: "Culiacán" }), updateOne({ _id: 3 }), deleteOne({ _id: 2 }))
db.system.profile.find(
  { ns: "comercial.clientes" },
  { op: 1, ns: 1, command: 1, user: 1, client: 1, appName: 1, ts: 1, millis: 1, nreturned: 1, docsExamined: 1, nModified: 1, ndeleted: 1 }
).sort({ ts: 1 });

// --- 10. Actividad 4 — Reducir el volumen con un filtro ---
db.setProfilingLevel(0);
db.system.profile.drop();
db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } });
db.getProfilingStatus();
// (Desde terminal app_ventas: find({ _id: 1 }) y updateOne({ _id: 1 }, { $set: { telefono: "6670000000" } }))
db.system.profile.find({}, { op: 1, ns: 1, user: 1, appName: 1, "command.q": 1, "command.u": 1, ts: 1 });

// --- 11. Actividad 5 — Accesos en la bitácora de mongod ---
bitacora()
  .filter(e => e.c === "ACCESS" && e.msg === "Failed to authenticate")
  .map(e => ({ t: e.t, id: e.id, ctx: e.ctx, user: e.attr.user, client: e.attr.client, error: e.attr.error, result: e.attr.result, app: e.attr.doc.application.name }));

bitacora()
  .filter(e => e.msg === "Successfully authenticated" && e.attr.user === "app_ventas")
  .slice(-1)
  .map(e => ({ t: e.t, id: e.id, ctx: e.ctx, client: e.attr.client, result: e.attr.result, app: e.attr.doc.application.name }));

// --- 12. Actividad 6 — Correlacionar un cambio de configuración con su autor ---
bitacora()
  .filter(e => e.msg === "Profiler settings changed")
  .map(e => ({ t: e.t, ctx: e.ctx, msg: e.msg, attr: e.attr }));

bitacora()
  .filter(e => e.ctx === "conn42" && e.msg === "Successfully authenticated")
  .map(e => ({ t: e.t, ctx: e.ctx, user: e.attr.user, db: e.attr.db, client: e.attr.client }));

// --- 13. Actividad 7 — Cambios de privilegios y control compensatorio ---
db.getSiblingDB("auditoria").instantaneas_privilegios.insertOne({
  momento: new Date(),
  tomada_por: db.runCommand({ connectionStatus: 1 }).authInfo.authenticatedUsers,
  usuarios: db.getUsers().users.map(u => ({ user: u.user, db: u.db, roles: u.roles }))
});

db.setProfilingLevel(2);
db.grantRolesToUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }]);

db.system.profile.countDocuments({ "command.grantRolesToUser": { $exists: true } });
bitacora().filter(e => JSON.stringify(e).includes("grantRoles")).length;

db.getSiblingDB("auditoria").instantaneas_privilegios.insertOne({
  momento: new Date(),
  tomada_por: db.runCommand({ connectionStatus: 1 }).authInfo.authenticatedUsers,
  usuarios: db.getUsers().users.map(u => ({ user: u.user, db: u.db, roles: u.roles }))
});

db.getSiblingDB("auditoria").instantaneas_privilegios.find({}, { _id: 0 }).sort({ momento: 1 });

db.revokeRolesFromUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }]);
db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } });
