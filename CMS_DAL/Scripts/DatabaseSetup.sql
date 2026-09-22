-- ==========================================================
-- Database Setup Script: Classes & Coaching Management System
-- Clean ADO.NET Schema (No EF Core Migrations Required)
-- ==========================================================

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'ClassesManagementDb')
BEGIN
    CREATE DATABASE ClassesManagementDb;
END
GO

USE ClassesManagementDb;
GO

-- 1. Roles Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Roles')
BEGIN
    CREATE TABLE Roles (
        RoleId INT IDENTITY(1,1) PRIMARY KEY,
        RoleName NVARCHAR(50) NOT NULL UNIQUE
    );
END
GO

-- 2. Users Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users (
        UserId INT IDENTITY(1,1) PRIMARY KEY,
        FullName NVARCHAR(100) NOT NULL,
        Email NVARCHAR(100) NOT NULL UNIQUE,
        Mobile NVARCHAR(20) NULL,
        PasswordHash NVARCHAR(255) NOT NULL,
        RoleId INT NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        UpdatedAt DATETIME2 NULL,
        CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId)
    );
    CREATE NONCLUSTERED INDEX IX_Users_Email ON Users(Email);
END
GO

-- 3. AcademicYears Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AcademicYears')
BEGIN
    CREATE TABLE AcademicYears (
        AcademicYearId INT IDENTITY(1,1) PRIMARY KEY,
        YearName NVARCHAR(50) NOT NULL,
        StartDate DATE NOT NULL,
        EndDate DATE NOT NULL,
        IsCurrent BIT NOT NULL DEFAULT 0,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 4. Courses Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Courses')
BEGIN
    CREATE TABLE Courses (
        CourseId INT IDENTITY(1,1) PRIMARY KEY,
        CourseName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(500) NULL,
        Duration NVARCHAR(50) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 5. Subjects Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Subjects')
BEGIN
    CREATE TABLE Subjects (
        SubjectId INT IDENTITY(1,1) PRIMARY KEY,
        SubjectName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(500) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 6. Teachers Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Teachers')
BEGIN
    CREATE TABLE Teachers (
        TeacherId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NOT NULL UNIQUE,
        EmployeeCode NVARCHAR(50) NULL UNIQUE,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        Mobile NVARCHAR(20) NULL,
        Email NVARCHAR(100) NULL,
        Qualification NVARCHAR(100) NULL,
        JoiningDate DATE NULL,
        ProfileImage NVARCHAR(255) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Teachers_Users FOREIGN KEY (UserId) REFERENCES Users(UserId)
    );
END
GO

-- 7. Students Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Students')
BEGIN
    CREATE TABLE Students (
        StudentId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NOT NULL UNIQUE,
        AdmissionNo NVARCHAR(50) NOT NULL UNIQUE,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        Gender NVARCHAR(10) NULL,
        DateOfBirth DATE NULL,
        Mobile NVARCHAR(20) NULL,
        Email NVARCHAR(100) NULL,
        Address NVARCHAR(255) NULL,
        ParentName NVARCHAR(100) NULL,
        ParentMobile NVARCHAR(20) NULL,
        AdmissionDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        ProfileImage NVARCHAR(255) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Students_Users FOREIGN KEY (UserId) REFERENCES Users(UserId)
    );
    CREATE NONCLUSTERED INDEX IX_Students_AdmissionNo ON Students(AdmissionNo);
END
GO

-- 8. StudentDocuments Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'StudentDocuments')
BEGIN
    CREATE TABLE StudentDocuments (
        DocumentId INT IDENTITY(1,1) PRIMARY KEY,
        StudentId INT NOT NULL,
        DocumentType NVARCHAR(50) NOT NULL,
        FilePath NVARCHAR(255) NOT NULL,
        UploadedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_StudentDocuments_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId) ON DELETE CASCADE
    );
END
GO

-- 9. Batches Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Batches')
BEGIN
    CREATE TABLE Batches (
        BatchId INT IDENTITY(1,1) PRIMARY KEY,
        CourseId INT NOT NULL,
        AcademicYearId INT NOT NULL,
        BatchName NVARCHAR(100) NOT NULL,
        StartDate DATE NULL,
        EndDate DATE NULL,
        StartTime TIME NULL,
        EndTime TIME NULL,
        Capacity INT NOT NULL DEFAULT 50,
        RoomNo NVARCHAR(50) NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Active',
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Batches_Courses FOREIGN KEY (CourseId) REFERENCES Courses(CourseId),
        CONSTRAINT FK_Batches_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES AcademicYears(AcademicYearId)
    );
END
GO

-- 10. BatchSubjects Table (Subject + Assigned Teacher per batch)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BatchSubjects')
BEGIN
    CREATE TABLE BatchSubjects (
        BatchSubjectId INT IDENTITY(1,1) PRIMARY KEY,
        BatchId INT NOT NULL,
        SubjectId INT NOT NULL,
        TeacherId INT NULL,
        CONSTRAINT FK_BatchSubjects_Batches FOREIGN KEY (BatchId) REFERENCES Batches(BatchId) ON DELETE CASCADE,
        CONSTRAINT FK_BatchSubjects_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId),
        CONSTRAINT FK_BatchSubjects_Teachers FOREIGN KEY (TeacherId) REFERENCES Teachers(TeacherId)
    );
END
GO

-- 11. Enrollments Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Enrollments')
BEGIN
    CREATE TABLE Enrollments (
        EnrollmentId INT IDENTITY(1,1) PRIMARY KEY,
        StudentId INT NOT NULL,
        BatchId INT NOT NULL,
        EnrollmentDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        StartDate DATE NULL,
        EndDate DATE NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Active',
        CONSTRAINT FK_Enrollments_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId),
        CONSTRAINT FK_Enrollments_Batches FOREIGN KEY (BatchId) REFERENCES Batches(BatchId)
    );
END
GO

-- 12. FeeStructures Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'FeeStructures')
BEGIN
    CREATE TABLE FeeStructures (
        FeeStructureId INT IDENTITY(1,1) PRIMARY KEY,
        CourseId INT NOT NULL,
        AcademicYearId INT NOT NULL,
        Name NVARCHAR(100) NOT NULL,
        TotalAmount DECIMAL(18,2) NOT NULL,
        Description NVARCHAR(500) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_FeeStructures_Courses FOREIGN KEY (CourseId) REFERENCES Courses(CourseId),
        CONSTRAINT FK_FeeStructures_AcademicYears FOREIGN KEY (AcademicYearId) REFERENCES AcademicYears(AcademicYearId)
    );
END
GO

-- 13. StudentFees Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'StudentFees')
BEGIN
    CREATE TABLE StudentFees (
        StudentFeeId INT IDENTITY(1,1) PRIMARY KEY,
        StudentId INT NOT NULL,
        FeeStructureId INT NOT NULL,
        TotalAmount DECIMAL(18,2) NOT NULL,
        DiscountAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
        FinalAmount DECIMAL(18,2) NOT NULL,
        DueDate DATE NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_StudentFees_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId),
        CONSTRAINT FK_StudentFees_FeeStructures FOREIGN KEY (FeeStructureId) REFERENCES FeeStructures(FeeStructureId)
    );
END
GO

-- 14. FeeInstallments Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'FeeInstallments')
BEGIN
    CREATE TABLE FeeInstallments (
        InstallmentId INT IDENTITY(1,1) PRIMARY KEY,
        StudentFeeId INT NOT NULL,
        InstallmentNo INT NOT NULL,
        Amount DECIMAL(18,2) NOT NULL,
        PaidAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
        BalanceAmount DECIMAL(18,2) NOT NULL,
        DueDate DATE NOT NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Unpaid',
        CONSTRAINT FK_FeeInstallments_StudentFees FOREIGN KEY (StudentFeeId) REFERENCES StudentFees(StudentFeeId) ON DELETE CASCADE
    );
END
GO

-- 15. PaymentSettings Table (Owner Static UPI QR & Info)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PaymentSettings')
BEGIN
    CREATE TABLE PaymentSettings (
        PaymentSettingId INT IDENTITY(1,1) PRIMARY KEY,
        UpiId NVARCHAR(100) NOT NULL,
        AccountName NVARCHAR(100) NOT NULL,
        QrImagePath NVARCHAR(255) NULL,
        Instructions NVARCHAR(500) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 16. Payments Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Payments')
BEGIN
    CREATE TABLE Payments (
        PaymentId INT IDENTITY(1,1) PRIMARY KEY,
        StudentFeeId INT NOT NULL,
        InstallmentId INT NULL,
        Amount DECIMAL(18,2) NOT NULL,
        PaymentDate DATETIME2 NOT NULL DEFAULT GETDATE(),
        PaymentMethod NVARCHAR(50) NOT NULL DEFAULT 'UPI',
        TransactionReference NVARCHAR(100) NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
        ReceiptNo NVARCHAR(50) NULL UNIQUE,
        ReceiptGeneratedAt DATETIME2 NULL,
        Remarks NVARCHAR(500) NULL,
        VerifiedBy INT NULL,
        VerifiedAt DATETIME2 NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Payments_StudentFees FOREIGN KEY (StudentFeeId) REFERENCES StudentFees(StudentFeeId),
        CONSTRAINT FK_Payments_FeeInstallments FOREIGN KEY (InstallmentId) REFERENCES FeeInstallments(InstallmentId),
        CONSTRAINT FK_Payments_VerifiedByUsers FOREIGN KEY (VerifiedBy) REFERENCES Users(UserId)
    );
END
GO

-- 17. PaymentProofs Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PaymentProofs')
BEGIN
    CREATE TABLE PaymentProofs (
        PaymentProofId INT IDENTITY(1,1) PRIMARY KEY,
        PaymentId INT NOT NULL,
        FilePath NVARCHAR(255) NOT NULL,
        OriginalFileName NVARCHAR(255) NULL,
        UploadedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        VerificationStatus NVARCHAR(20) NOT NULL DEFAULT 'Pending',
        CONSTRAINT FK_PaymentProofs_Payments FOREIGN KEY (PaymentId) REFERENCES Payments(PaymentId) ON DELETE CASCADE
    );
END
GO

-- 18. ClassSessions Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ClassSessions')
BEGIN
    CREATE TABLE ClassSessions (
        SessionId INT IDENTITY(1,1) PRIMARY KEY,
        BatchId INT NOT NULL,
        SubjectId INT NOT NULL,
        TeacherId INT NULL,
        SessionDate DATE NOT NULL,
        StartTime TIME NULL,
        EndTime TIME NULL,
        Topic NVARCHAR(255) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_ClassSessions_Batches FOREIGN KEY (BatchId) REFERENCES Batches(BatchId),
        CONSTRAINT FK_ClassSessions_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId),
        CONSTRAINT FK_ClassSessions_Teachers FOREIGN KEY (TeacherId) REFERENCES Teachers(TeacherId)
    );
END
GO

-- 19. Attendance Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Attendance')
BEGIN
    CREATE TABLE Attendance (
        AttendanceId INT IDENTITY(1,1) PRIMARY KEY,
        SessionId INT NOT NULL,
        StudentId INT NOT NULL,
        Status NVARCHAR(20) NOT NULL,
        Remarks NVARCHAR(255) NULL,
        MarkedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Attendance_ClassSessions FOREIGN KEY (SessionId) REFERENCES ClassSessions(SessionId) ON DELETE CASCADE,
        CONSTRAINT FK_Attendance_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId)
    );
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Attendance_Session_Student ON Attendance(SessionId, StudentId);
END
GO

-- 20. Exams Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Exams')
BEGIN
    CREATE TABLE Exams (
        ExamId INT IDENTITY(1,1) PRIMARY KEY,
        BatchId INT NOT NULL,
        ExamName NVARCHAR(100) NOT NULL,
        ExamDate DATE NOT NULL,
        TotalMarks INT NOT NULL,
        Description NVARCHAR(500) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Exams_Batches FOREIGN KEY (BatchId) REFERENCES Batches(BatchId)
    );
END
GO

-- 21. ExamSubjects Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ExamSubjects')
BEGIN
    CREATE TABLE ExamSubjects (
        ExamSubjectId INT IDENTITY(1,1) PRIMARY KEY,
        ExamId INT NOT NULL,
        SubjectId INT NOT NULL,
        MaxMarks INT NOT NULL,
        CONSTRAINT FK_ExamSubjects_Exams FOREIGN KEY (ExamId) REFERENCES Exams(ExamId) ON DELETE CASCADE,
        CONSTRAINT FK_ExamSubjects_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId)
    );
END
GO

-- 22. Results Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Results')
BEGIN
    CREATE TABLE Results (
        ResultId INT IDENTITY(1,1) PRIMARY KEY,
        ExamId INT NOT NULL,
        StudentId INT NOT NULL,
        SubjectId INT NOT NULL,
        MarksObtained DECIMAL(5,2) NOT NULL,
        Remarks NVARCHAR(255) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Results_Exams FOREIGN KEY (ExamId) REFERENCES Exams(ExamId),
        CONSTRAINT FK_Results_Students FOREIGN KEY (StudentId) REFERENCES Students(StudentId),
        CONSTRAINT FK_Results_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId)
    );
END
GO

-- 23. StudyMaterials Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'StudyMaterials')
BEGIN
    CREATE TABLE StudyMaterials (
        MaterialId INT IDENTITY(1,1) PRIMARY KEY,
        BatchId INT NOT NULL,
        SubjectId INT NOT NULL,
        Title NVARCHAR(150) NOT NULL,
        Description NVARCHAR(500) NULL,
        FilePath NVARCHAR(255) NOT NULL,
        UploadedBy INT NULL,
        UploadedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_StudyMaterials_Batches FOREIGN KEY (BatchId) REFERENCES Batches(BatchId),
        CONSTRAINT FK_StudyMaterials_Subjects FOREIGN KEY (SubjectId) REFERENCES Subjects(SubjectId),
        CONSTRAINT FK_StudyMaterials_Teachers FOREIGN KEY (UploadedBy) REFERENCES Teachers(TeacherId)
    );
END
GO

-- 24. Inquiries Table (Admissions CRM)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Inquiries')
BEGIN
    CREATE TABLE Inquiries (
        InquiryId INT IDENTITY(1,1) PRIMARY KEY,
        StudentName NVARCHAR(100) NOT NULL,
        Mobile NVARCHAR(20) NOT NULL,
        Email NVARCHAR(100) NULL,
        CourseInterested NVARCHAR(100) NULL,
        Status NVARCHAR(30) NOT NULL DEFAULT 'New',
        NextFollowUpDate DATE NULL,
        Remarks NVARCHAR(500) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 25. Expenses Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Expenses')
BEGIN
    CREATE TABLE Expenses (
        ExpenseId INT IDENTITY(1,1) PRIMARY KEY,
        Title NVARCHAR(100) NOT NULL,
        Category NVARCHAR(50) NOT NULL,
        Amount DECIMAL(18,2) NOT NULL,
        ExpenseDate DATE NOT NULL,
        Remarks NVARCHAR(500) NULL,
        ReceiptPath NVARCHAR(255) NULL,
        CreatedBy INT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_Expenses_Users FOREIGN KEY (CreatedBy) REFERENCES Users(UserId)
    );
END
GO

-- 26. Notices Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Notices')
BEGIN
    CREATE TABLE Notices (
        NoticeId INT IDENTITY(1,1) PRIMARY KEY,
        Title NVARCHAR(150) NOT NULL,
        Description NVARCHAR(MAX) NOT NULL,
        TargetRole NVARCHAR(20) NOT NULL DEFAULT 'All',
        PublishedDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        ExpiryDate DATE NULL,
        CreatedBy INT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CONSTRAINT FK_Notices_Users FOREIGN KEY (CreatedBy) REFERENCES Users(UserId)
    );
END
GO

-- 27. AuditLogs Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditLogs')
BEGIN
    CREATE TABLE AuditLogs (
        AuditLogId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NULL,
        Action NVARCHAR(100) NOT NULL,
        EntityName NVARCHAR(100) NULL,
        EntityId INT NULL,
        Description NVARCHAR(500) NULL,
        IpAddress NVARCHAR(50) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
    );
END
GO

-- ==========================================================
-- SEED DATA (Phase 1 Baseline)
-- ==========================================================

-- Seed Roles
IF NOT EXISTS (SELECT * FROM Roles WHERE RoleName = 'Admin')
    INSERT INTO Roles (RoleName) VALUES ('Admin');
IF NOT EXISTS (SELECT * FROM Roles WHERE RoleName = 'Teacher')
    INSERT INTO Roles (RoleName) VALUES ('Teacher');
IF NOT EXISTS (SELECT * FROM Roles WHERE RoleName = 'Student')
    INSERT INTO Roles (RoleName) VALUES ('Student');
GO

-- Seed Default Academic Year
IF NOT EXISTS (SELECT * FROM AcademicYears WHERE YearName = '2025-2026')
BEGIN
    INSERT INTO AcademicYears (YearName, StartDate, EndDate, IsCurrent)
    VALUES ('2025-2026', '2025-04-01', '2026-03-31', 1);
END
GO

-- Seed Sample Courses
IF NOT EXISTS (SELECT * FROM Courses WHERE CourseName = '12th Science (PCM)')
BEGIN
    INSERT INTO Courses (CourseName, Description, Duration, IsActive)
    VALUES ('12th Science (PCM)', 'Complete 12th Board syllabus with competitive foundation', '1 Year', 1);
END
IF NOT EXISTS (SELECT * FROM Courses WHERE CourseName = 'JEE Main & Advanced')
BEGIN
    INSERT INTO Courses (CourseName, Description, Duration, IsActive)
    VALUES ('JEE Main & Advanced', 'Intensive coaching for IIT JEE aspirants', '2 Years', 1);
END
GO

-- Seed Sample Subjects
IF NOT EXISTS (SELECT * FROM Subjects WHERE SubjectName = 'Physics')
    INSERT INTO Subjects (SubjectName, Description, IsActive) VALUES ('Physics', 'Mechanics, Electromagnetism, Modern Physics', 1);
IF NOT EXISTS (SELECT * FROM Subjects WHERE SubjectName = 'Chemistry')
    INSERT INTO Subjects (SubjectName, Description, IsActive) VALUES ('Chemistry', 'Physical, Inorganic, and Organic Chemistry', 1);
IF NOT EXISTS (SELECT * FROM Subjects WHERE SubjectName = 'Mathematics')
    INSERT INTO Subjects (SubjectName, Description, IsActive) VALUES ('Mathematics', 'Calculus, Algebra, Coordinate Geometry', 1);
GO

-- Seed Payment Settings (Static UPI QR placeholder)
IF NOT EXISTS (SELECT * FROM PaymentSettings)
BEGIN
    INSERT INTO PaymentSettings (UpiId, AccountName, Instructions, IsActive)
    VALUES ('classes@upi', 'Excellence Classes Official', 'Scan QR using any UPI app (GPay/PhonePe/Paytm), pay the due amount and upload the screenshot with UTR/Transaction ID.', 1);
END
GO
