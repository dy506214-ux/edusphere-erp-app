const { Client } = require('pg');

async function main() {
  const dbUri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres";
  const client = new Client({ connectionString: dbUri });

  try {
    await client.connect();
    console.log("Connected to Supabase PostgreSQL.");

    // Check count of scanners
    const countRes = await client.query('SELECT COUNT(*) FROM public."QRScanner"');
    const count = parseInt(countRes.rows[0].count);
    console.log(`Current scanners count: ${count}`);

    if (count === 0) {
      console.log("Seeding scanners...");
      
      const adminRes = await client.query('SELECT id FROM public."User" WHERE role = \'SUPER_ADMIN\' OR role = \'ADMIN\' LIMIT 1');
      const adminId = adminRes.rows[0]?.id || "2187df86-57b7-4f83-bba6-8a4fb74e3f62"; // fallback

      const studentRes = await client.query('SELECT id FROM public."Student" LIMIT 5');
      const studentIds = studentRes.rows.map(r => r.id);

      const scanners = [
        {
          id: "scn-gate-entry-001",
          name: "Main Campus Entrance",
          location: "Main Gate Entry",
          scannerType: "ENTRY",
          latitude: 28.5678,
          longitude: 77.1234,
          geofenceRadius: 100,
          allowedRoles: ["STUDENT", "TEACHER", "PARENT", "STAFF"],
          isActive: true,
          createdBy: adminId
        },
        {
          id: "scn-gate-exit-002",
          name: "Main Campus Exit",
          location: "Main Gate Exit",
          scannerType: "EXIT",
          latitude: 28.5678,
          longitude: 77.1234,
          geofenceRadius: 100,
          allowedRoles: ["STUDENT", "TEACHER", "PARENT", "STAFF"],
          isActive: true,
          createdBy: adminId
        },
        {
          id: "scn-lib-003",
          name: "Central Library Desk",
          location: "Academic Block A, 2nd Floor",
          scannerType: "LIBRARY",
          latitude: 28.5680,
          longitude: 77.1236,
          geofenceRadius: 50,
          allowedRoles: ["STUDENT", "TEACHER", "STAFF"],
          isActive: true,
          createdBy: adminId
        },
        {
          id: "scn-hall-004",
          name: "Exam Hall Scanner 1",
          location: "Auditorium Hall B",
          scannerType: "EXAM_HALL",
          latitude: 28.5682,
          longitude: 77.1238,
          geofenceRadius: 30,
          allowedRoles: ["STUDENT"],
          isActive: true,
          createdBy: adminId
        },
        {
          id: "scn-cls-005",
          name: "Classroom 12-A",
          location: "Science Wing, Room 302",
          scannerType: "CLASSROOM",
          latitude: 28.5685,
          longitude: 77.1240,
          geofenceRadius: 20,
          allowedRoles: ["STUDENT", "TEACHER"],
          isActive: false,
          createdBy: adminId
        }
      ];

      for (const sc of scanners) {
        await client.query(`
          INSERT INTO public."QRScanner" (
            "id", "name", "location", "scannerType", "latitude", "longitude", 
            "geofenceRadius", "allowedRoles", "isActive", "createdBy", "createdAt", "updatedAt"
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW())
        `, [
          sc.id, sc.name, sc.location, sc.scannerType, sc.latitude, sc.longitude,
          sc.geofenceRadius, sc.allowedRoles, sc.isActive, sc.createdBy
        ]);
        console.log(`Seeded scanner: ${sc.name}`);
      }

      // Proactively create some dummy attendance records for today to show scans count!
      console.log("Seeding today's attendance scans...");
      const today = new Date();
      const todayStr = today.toISOString().substring(0, 10);

      // Delete today's scanner test records to allow repeat runs cleanly
      await client.query('DELETE FROM public."AttendanceRecord" WHERE "scannerId" IS NOT NULL AND "date" = $1', [todayStr]);

      for (let i = 0; i < studentIds.length; i++) {
        const studentId = studentIds[i];
        
        // Gate Entry scan
        await client.query(`
          INSERT INTO public."AttendanceRecord" (
            "id", "attendeeType", "studentId", "date", "checkInTime", 
            "status", "scannedByRFID", "scannedByQR", "scannerId", "createdAt", "updatedAt"
          ) VALUES ($1, 'STUDENT', $2, $3, $4, 'PRESENT', false, true, $5, $6, $6)
        `, [
          `scan-test-${i}-entry`, studentId, todayStr, new Date(today.getTime() - 4 * 60 * 60 * 1000), // 4 hrs ago
          "scn-gate-entry-001", new Date(today.getTime() - 4 * 60 * 60 * 1000)
        ]);

        if (i % 2 === 0) {
          // Library scan
          await client.query(`
            INSERT INTO public."AttendanceRecord" (
              "id", "attendeeType", "studentId", "date", "checkInTime", 
              "status", "scannedByRFID", "scannedByQR", "scannerId", "createdAt", "updatedAt"
            ) VALUES ($1, 'STUDENT', $2, $3, $4, 'PRESENT', false, true, $5, $6, $6)
          `, [
            `scan-test-${i}-lib`, studentId, todayStr, new Date(today.getTime() - 2 * 60 * 60 * 1000), // 2 hrs ago
            "scn-lib-003", new Date(today.getTime() - 2 * 60 * 60 * 1000)
          ]);
        }
      }
      console.log("Seeding today's attendance scans completed!");
    } else {
      console.log("Scanners table already contains data.");
    }

  } catch (err) {
    console.error("Error seeding scanners:", err);
  } finally {
    await client.end();
  }
}

main();
