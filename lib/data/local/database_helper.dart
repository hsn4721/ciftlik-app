import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ciftlikpro.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bulk_milking (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session TEXT NOT NULL,
          date TEXT NOT NULL,
          animalCount INTEGER NOT NULL,
          totalAmount REAL NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS milk_tank_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          balanceAfter REAL NOT NULL,
          notes TEXT,
          date TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE finance ADD COLUMN relatedAnimalId INTEGER');
      await db.execute('ALTER TABLE finance ADD COLUMN invoiceNo TEXT');
      await db.execute('ALTER TABLE finance ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE health ADD COLUMN nextVisit TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE feed_stock ADD COLUMN unitPrice REAL');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS feed_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stockId INTEGER NOT NULL UNIQUE,
          morningAmount REAL NOT NULL DEFAULT 0,
          eveningAmount REAL NOT NULL DEFAULT 0,
          updatedAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS feed_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          session TEXT NOT NULL,
          totalCost REAL,
          notes TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      // Fix calves.motherId: TEXT → INTEGER via table recreation
      await db.execute('''
        CREATE TABLE calves_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          animalId INTEGER,
          earTag TEXT NOT NULL,
          name TEXT,
          gender TEXT NOT NULL,
          birthDate TEXT NOT NULL,
          motherId INTEGER,
          fatherBreed TEXT,
          birthWeight REAL,
          status TEXT NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO calves_new
          (id, animalId, earTag, name, gender, birthDate, motherId,
           fatherBreed, birthWeight, status, notes, createdAt)
        SELECT
          id, animalId, earTag, name, gender, birthDate,
          CAST(motherId AS INTEGER),
          fatherBreed, birthWeight, status, notes, createdAt
        FROM calves
      ''');
      await db.execute('DROP TABLE calves');
      await db.execute('ALTER TABLE calves_new RENAME TO calves');

      // Performance indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_animals_status ON animals(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_milking_date ON milking(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_milking_animalId ON milking(animalId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_health_animalId ON health(animalId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_vaccines_nextDate ON vaccines(nextVaccineDate)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_finance_date ON finance(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bulk_milking_date ON bulk_milking(date)');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE animals ADD COLUMN purchasePrice REAL');
      await db.execute('ALTER TABLE animals ADD COLUMN exitType TEXT');
      await db.execute('ALTER TABLE animals ADD COLUMN exitDate TEXT');
      await db.execute('ALTER TABLE animals ADD COLUMN exitPrice REAL');
    }
    if (oldVersion < 8) {
      await db.execute("ALTER TABLE finance ADD COLUMN period TEXT NOT NULL DEFAULT 'monthly'");
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Animals
    await db.execute('''
      CREATE TABLE animals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        earTag TEXT NOT NULL,
        name TEXT,
        breed TEXT NOT NULL,
        gender TEXT NOT NULL,
        birthDate TEXT NOT NULL,
        status TEXT NOT NULL,
        weight REAL,
        photoPath TEXT,
        motherId INTEGER,
        fatherId INTEGER,
        entryDate TEXT NOT NULL,
        entryType TEXT NOT NULL,
        purchasePrice REAL,
        exitType TEXT,
        exitDate TEXT,
        exitPrice REAL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Milking
    await db.execute('''
      CREATE TABLE milking (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animalId INTEGER NOT NULL,
        date TEXT NOT NULL,
        session TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Calves
    await db.execute('''
      CREATE TABLE calves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animalId INTEGER,
        earTag TEXT NOT NULL,
        name TEXT,
        gender TEXT NOT NULL,
        birthDate TEXT NOT NULL,
        motherId INTEGER,
        fatherBreed TEXT,
        birthWeight REAL,
        status TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Breeding
    await db.execute('''
      CREATE TABLE breeding (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animalId INTEGER NOT NULL,
        breedingType TEXT NOT NULL,
        breedingDate TEXT NOT NULL,
        bullBreed TEXT,
        expectedBirthDate TEXT,
        status TEXT NOT NULL,
        actualBirthDate TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Health
    await db.execute('''
      CREATE TABLE health (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animalId INTEGER NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        diagnosis TEXT,
        treatment TEXT,
        medicine TEXT,
        dose TEXT,
        milkWithdrawal INTEGER DEFAULT 0,
        milkWithdrawalEnd TEXT,
        vetName TEXT,
        cost REAL,
        nextVisit TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Vaccines
    await db.execute('''
      CREATE TABLE vaccines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animalId INTEGER,
        isHerdWide INTEGER DEFAULT 0,
        vaccineName TEXT NOT NULL,
        vaccineDate TEXT NOT NULL,
        nextVaccineDate TEXT,
        dose TEXT,
        vetName TEXT,
        cost REAL,
        batchNumber TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Feed stock
    await db.execute('''
      CREATE TABLE feed_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL,
        unitPrice REAL,
        minQuantity REAL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Feed transactions
    await db.execute('''
      CREATE TABLE feed_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stockId INTEGER NOT NULL,
        transactionType TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        unitPrice REAL,
        date TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Finance
    await db.execute('''
      CREATE TABLE finance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        relatedAnimalId INTEGER,
        invoiceNo TEXT,
        notes TEXT,
        period TEXT NOT NULL DEFAULT 'monthly',
        createdAt TEXT NOT NULL
      )
    ''');

    // Staff
    await db.execute('''
      CREATE TABLE staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        startDate TEXT,
        salary REAL,
        isActive INTEGER DEFAULT 1,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Tasks
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        assignedToId INTEGER,
        dueDate TEXT,
        isCompleted INTEGER DEFAULT 0,
        priority TEXT NOT NULL DEFAULT 'Normal',
        createdAt TEXT NOT NULL
      )
    ''');

    // Equipment
    await db.execute('''
      CREATE TABLE equipment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        brand TEXT,
        model TEXT,
        serialNumber TEXT,
        purchaseDate TEXT,
        purchasePrice REAL,
        status TEXT NOT NULL DEFAULT 'Çalışıyor',
        lastMaintenanceDate TEXT,
        nextMaintenanceDate TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Bulk milking sessions
    await db.execute('''
      CREATE TABLE bulk_milking (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session TEXT NOT NULL,
        date TEXT NOT NULL,
        animalCount INTEGER NOT NULL,
        totalAmount REAL NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Milk tank log
    await db.execute('''
      CREATE TABLE milk_tank_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        balanceAfter REAL NOT NULL,
        notes TEXT,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Feed plans (daily morning/evening plan per stock)
    await db.execute('''
      CREATE TABLE feed_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stockId INTEGER NOT NULL UNIQUE,
        morningAmount REAL NOT NULL DEFAULT 0,
        eveningAmount REAL NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Feed sessions (applied feedings)
    await db.execute('''
      CREATE TABLE feed_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        session TEXT NOT NULL,
        totalCost REAL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Subsidies (kept for potential future use)
    await db.execute('''
      CREATE TABLE subsidies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        applicationDate TEXT,
        status TEXT NOT NULL,
        receivedAmount REAL,
        receivedDate TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
