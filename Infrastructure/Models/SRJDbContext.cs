using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;

namespace SRJBackend.Infrastructure.Models;

public partial class SRJDbContext : DbContext
{
    public SRJDbContext()
    {
    }

    public SRJDbContext(DbContextOptions<SRJDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<AuditLog> AuditLogs { get; set; }

    public virtual DbSet<ChildbirthType> ChildbirthTypes { get; set; }

    public virtual DbSet<CivilState> CivilStates { get; set; }

    public virtual DbSet<Department> Departments { get; set; }

    public virtual DbSet<Disability> Disabilities { get; set; }

    public virtual DbSet<DisabilityDegree> DisabilityDegrees { get; set; }

    public virtual DbSet<DisabilityType> DisabilityTypes { get; set; }

    public virtual DbSet<District> Districts { get; set; }

    public virtual DbSet<DocumentType> DocumentTypes { get; set; }

    public virtual DbSet<EducationalPerson> EducationalPeople { get; set; }

    public virtual DbSet<Enrollment> Enrollments { get; set; }

    public virtual DbSet<EthnicSelfIdentification> EthnicSelfIdentifications { get; set; }

    public virtual DbSet<Familiar> Familiars { get; set; }

    public virtual DbSet<FamiliarRelationshipType> FamiliarRelationshipTypes { get; set; }

    public virtual DbSet<FamiliarStudentRelationship> FamiliarStudentRelationships { get; set; }

    public virtual DbSet<Gender> Genders { get; set; }

    public virtual DbSet<Grade> Grades { get; set; }

    public virtual DbSet<GradeOffering> GradeOfferings { get; set; }

    public virtual DbSet<GradeOfferingShift> GradeOfferingShifts { get; set; }

    public virtual DbSet<GradeOfferingShiftSection> GradeOfferingShiftSections { get; set; }

    public virtual DbSet<Institution> Institutions { get; set; }

    public virtual DbSet<InstitutionLevel> InstitutionLevels { get; set; }

    public virtual DbSet<Language> Languages { get; set; }

    public virtual DbSet<Level> Levels { get; set; }

    public virtual DbSet<LevelOfEducation> LevelOfEducations { get; set; }

    public virtual DbSet<PaymentMethod> PaymentMethods { get; set; }

    public virtual DbSet<Permission> Permissions { get; set; }

    public virtual DbSet<Person> People { get; set; }

    public virtual DbSet<Province> Provinces { get; set; }

    public virtual DbSet<Religion> Religions { get; set; }

    public virtual DbSet<Role> Roles { get; set; }

    public virtual DbSet<RucState> RucStates { get; set; }

    public virtual DbSet<SchoolFee> SchoolFees { get; set; }

    public virtual DbSet<SchoolFeeConcept> SchoolFeeConcepts { get; set; }

    public virtual DbSet<SchoolYear> SchoolYears { get; set; }

    public virtual DbSet<Shift> Shifts { get; set; }

    public virtual DbSet<Student> Students { get; set; }

    public virtual DbSet<StudentHome> StudentHomes { get; set; }

    public virtual DbSet<StudentState> StudentStates { get; set; }

    public virtual DbSet<StudentStatesByYear> StudentStatesByYears { get; set; }

    public virtual DbSet<Ubigeo> Ubigeos { get; set; }

    public virtual DbSet<User> Users { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
#warning To protect potentially sensitive information in your connection string, you should move it out of source code. You can avoid scaffolding the connection string by using the Name= syntax to read it from configuration - see https://go.microsoft.com/fwlink/?linkid=2131148. For more guidance on storing connection strings, see https://go.microsoft.com/fwlink/?LinkId=723263.
        => optionsBuilder.UseNpgsql("Host=localhost;Database=SRJdb;Username=postgres;Password=***REMOVED***");

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AuditLog>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("audit_log_pkey");

            entity.ToTable("audit_log");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("now()")
                .HasColumnName("created_at");
            entity.Property(e => e.EventData)
                .HasColumnType("jsonb")
                .HasColumnName("event_data");
            entity.Property(e => e.EventType)
                .HasMaxLength(200)
                .HasColumnName("event_type");
        });

        modelBuilder.Entity<ChildbirthType>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("childbirth_type_pkey");

            entity.ToTable("childbirth_type");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(50)
                .HasColumnName("name");
        });

        modelBuilder.Entity<CivilState>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("civil_state_pkey");

            entity.ToTable("civil_state");

            entity.HasIndex(e => e.Name, "civil_state_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(40)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Department>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("department_pkey");

            entity.ToTable("department");

            entity.HasIndex(e => e.Code, "department_code_key").IsUnique();

            entity.HasIndex(e => e.Name, "department_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code)
                .HasMaxLength(2)
                .IsFixedLength()
                .HasColumnName("code");
            entity.Property(e => e.Name)
                .HasMaxLength(100)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Disability>(entity =>
        {
            entity.HasKey(e => e.StudentId).HasName("disabilities_pkey");

            entity.ToTable("disabilities");

            entity.Property(e => e.StudentId)
                .ValueGeneratedNever()
                .HasColumnName("student_id");
            entity.Property(e => e.DisabilityCertificateNumber)
                .HasMaxLength(50)
                .HasColumnName("disability_certificate_number");
            entity.Property(e => e.DisabilityDegreeId).HasColumnName("disability_degree_id");
            entity.Property(e => e.DisabilityTypeId).HasColumnName("disability_type_id");
            entity.Property(e => e.HasDisabilityCertificate).HasColumnName("has_disability_certificate");

            entity.HasOne(d => d.DisabilityDegree).WithMany(p => p.Disabilities)
                .HasForeignKey(d => d.DisabilityDegreeId)
                .HasConstraintName("disabilities_disability_degree_id_fkey");

            entity.HasOne(d => d.DisabilityType).WithMany(p => p.Disabilities)
                .HasForeignKey(d => d.DisabilityTypeId)
                .HasConstraintName("disabilities_disability_type_id_fkey");

            entity.HasOne(d => d.Student).WithOne(p => p.Disability)
                .HasForeignKey<Disability>(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("disabilities_student_id_fkey");
        });

        modelBuilder.Entity<DisabilityDegree>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("disability_degrees_pkey");

            entity.ToTable("disability_degrees");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Degree)
                .HasMaxLength(30)
                .HasColumnName("degree");
        });

        modelBuilder.Entity<DisabilityType>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("disability_types_pkey");

            entity.ToTable("disability_types");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Type)
                .HasMaxLength(40)
                .HasColumnName("type");
        });

        modelBuilder.Entity<District>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("district_pkey");

            entity.ToTable("district");

            entity.HasIndex(e => new { e.Code, e.ProvinceId }, "district_code_province_id_key").IsUnique();

            entity.HasIndex(e => e.ProvinceId, "idx_district_province_id");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code)
                .HasMaxLength(2)
                .IsFixedLength()
                .HasColumnName("code");
            entity.Property(e => e.Name)
                .HasMaxLength(100)
                .HasColumnName("name");
            entity.Property(e => e.ProvinceId).HasColumnName("province_id");

            entity.HasOne(d => d.Province).WithMany(p => p.Districts)
                .HasForeignKey(d => d.ProvinceId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("district_province_id_fkey");
        });

        modelBuilder.Entity<DocumentType>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("document_types_pkey");

            entity.ToTable("document_types");

            entity.HasIndex(e => e.Name, "document_types_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(30)
                .HasColumnName("name");
        });

        modelBuilder.Entity<EducationalPerson>(entity =>
        {
            entity.HasKey(e => e.PersonId).HasName("educational_person_pkey");

            entity.ToTable("educational_person");

            entity.Property(e => e.PersonId)
                .ValueGeneratedNever()
                .HasColumnName("person_id");
            entity.Property(e => e.EthnicSelfIdentificationId).HasColumnName("ethnic_self_identification_id");
            entity.Property(e => e.NativeLanguageId).HasColumnName("native_language_id");

            entity.HasOne(d => d.EthnicSelfIdentification).WithMany(p => p.EducationalPeople)
                .HasForeignKey(d => d.EthnicSelfIdentificationId)
                .HasConstraintName("educational_person_ethnic_self_identification_id_fkey");

            entity.HasOne(d => d.NativeLanguage).WithMany(p => p.EducationalPeople)
                .HasForeignKey(d => d.NativeLanguageId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("educational_person_native_language_id_fkey");

            entity.HasOne(d => d.Person).WithOne(p => p.EducationalPerson)
                .HasForeignKey<EducationalPerson>(d => d.PersonId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("educational_person_person_id_fkey");

            entity.HasMany(d => d.SecondLanguages).WithMany(p => p.EducationalPeopleNavigation)
                .UsingEntity<Dictionary<string, object>>(
                    "SecondLanguage",
                    r => r.HasOne<Language>().WithMany()
                        .HasForeignKey("SecondLanguageId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("second_languages_second_language_id_fkey"),
                    l => l.HasOne<EducationalPerson>().WithMany()
                        .HasForeignKey("EducationalPersonId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("second_languages_educational_person_id_fkey"),
                    j =>
                    {
                        j.HasKey("EducationalPersonId", "SecondLanguageId").HasName("second_languages_pkey");
                        j.ToTable("second_languages");
                        j.IndexerProperty<int>("EducationalPersonId").HasColumnName("educational_person_id");
                        j.IndexerProperty<int>("SecondLanguageId").HasColumnName("second_language_id");
                    });
        });

        modelBuilder.Entity<Enrollment>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("enrollment_pkey");

            entity.ToTable("enrollment");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code)
                .HasMaxLength(11)
                .IsFixedLength()
                .HasColumnName("code");
            entity.Property(e => e.CodeNumber).HasColumnName("code_number");
            entity.Property(e => e.GradeOfferingShiftSectionId).HasColumnName("grade_offering_shift_section_id");
            entity.Property(e => e.PreviousSchool).HasColumnName("previous_school");
            entity.Property(e => e.SchoolFeeConceptId).HasColumnName("school_fee_concept_id");
            entity.Property(e => e.SchoolYearId).HasColumnName("school_year_id");
            entity.Property(e => e.StudentId).HasColumnName("student_id");

            entity.HasOne(d => d.GradeOfferingShiftSection).WithMany(p => p.Enrollments)
                .HasForeignKey(d => d.GradeOfferingShiftSectionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("enrollment_grade_offering_shift_section_id_fkey");

            entity.HasOne(d => d.SchoolFeeConcept).WithMany(p => p.Enrollments)
                .HasForeignKey(d => d.SchoolFeeConceptId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("enrollment_school_fee_concept_id_fkey");

            entity.HasOne(d => d.SchoolYear).WithMany(p => p.Enrollments)
                .HasForeignKey(d => d.SchoolYearId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("enrollment_school_year_id_fkey");

            entity.HasOne(d => d.Student).WithMany(p => p.Enrollments)
                .HasForeignKey(d => d.StudentId)
                .HasConstraintName("enrollment_student_id_fkey");
        });

        modelBuilder.Entity<EthnicSelfIdentification>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("ethnic_self_identifications_pkey");

            entity.ToTable("ethnic_self_identifications");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.EthnicSelfIdentification1)
                .HasMaxLength(100)
                .HasColumnName("ethnic_self_identification");
        });

        modelBuilder.Entity<Familiar>(entity =>
        {
            entity.HasKey(e => e.EducationalPersonId).HasName("familiars_pkey");

            entity.ToTable("familiars");

            entity.Property(e => e.EducationalPersonId)
                .ValueGeneratedNever()
                .HasColumnName("educational_person_id");
            entity.Property(e => e.LevelOfEducationId).HasColumnName("level_of_education_id");
            entity.Property(e => e.Lives).HasColumnName("lives");
            entity.Property(e => e.Occupation)
                .HasMaxLength(70)
                .HasColumnName("occupation");
            entity.Property(e => e.Workplace)
                .HasMaxLength(100)
                .HasColumnName("workplace");

            entity.HasOne(d => d.EducationalPerson).WithOne(p => p.Familiar)
                .HasForeignKey<Familiar>(d => d.EducationalPersonId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("familiars_educational_person_id_fkey");

            entity.HasOne(d => d.LevelOfEducation).WithMany(p => p.Familiars)
                .HasForeignKey(d => d.LevelOfEducationId)
                .HasConstraintName("familiars_level_of_education_id_fkey");
        });

        modelBuilder.Entity<FamiliarRelationshipType>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("familiar_relationship_type_pkey");

            entity.ToTable("familiar_relationship_type");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(100)
                .HasColumnName("name");
        });

        modelBuilder.Entity<FamiliarStudentRelationship>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("familiar_student_relationship_pkey");

            entity.ToTable("familiar_student_relationship");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.FamiliarId).HasColumnName("familiar_id");
            entity.Property(e => e.FamiliarRelationshipTypeId).HasColumnName("familiar_relationship_type_id");
            entity.Property(e => e.Isguardian).HasColumnName("isguardian");
            entity.Property(e => e.LivesTogether).HasColumnName("lives_together");
            entity.Property(e => e.StudentId).HasColumnName("student_id");

            entity.HasOne(d => d.Familiar).WithMany(p => p.FamiliarStudentRelationships)
                .HasForeignKey(d => d.FamiliarId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("familiar_student_relationship_familiar_id_fkey");

            entity.HasOne(d => d.FamiliarRelationshipType).WithMany(p => p.FamiliarStudentRelationships)
                .HasForeignKey(d => d.FamiliarRelationshipTypeId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("familiar_student_relationship_familiar_relationship_type_i_fkey");

            entity.HasOne(d => d.Student).WithMany(p => p.FamiliarStudentRelationships)
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("familiar_student_relationship_student_id_fkey");
        });

        modelBuilder.Entity<Gender>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("genders_pkey");

            entity.ToTable("genders");

            entity.HasIndex(e => e.Name, "genders_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(50)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Grade>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("academic_grades_pkey");

            entity.ToTable("grades");

            entity.Property(e => e.Id)
                .HasDefaultValueSql("nextval('academic_grades_id_seq'::regclass)")
                .HasColumnName("id");
            entity.Property(e => e.LevelId).HasColumnName("level_id");
            entity.Property(e => e.Name)
                .HasMaxLength(50)
                .HasColumnName("name");
            entity.Property(e => e.Year).HasColumnName("year");

            entity.HasOne(d => d.Level).WithMany(p => p.Grades)
                .HasForeignKey(d => d.LevelId)
                .HasConstraintName("academic_grades_level_id_fkey");
        });

        modelBuilder.Entity<GradeOffering>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("grade_offerings_pkey");

            entity.ToTable("grade_offerings");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.GradeId).HasColumnName("grade_id");
            entity.Property(e => e.SchoolYearId).HasColumnName("school_year_id");

            entity.HasOne(d => d.Grade).WithMany(p => p.GradeOfferings)
                .HasForeignKey(d => d.GradeId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("grade_offerings_grade_id_fkey");

            entity.HasOne(d => d.SchoolYear).WithMany(p => p.GradeOfferings)
                .HasForeignKey(d => d.SchoolYearId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("grade_offerings_school_year_id_fkey");
        });

        modelBuilder.Entity<GradeOfferingShift>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("grade_offering_shifts_pkey");

            entity.ToTable("grade_offering_shifts");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.GradeOfferingId).HasColumnName("grade_offering_id");
            entity.Property(e => e.Sections).HasColumnName("sections");
            entity.Property(e => e.ShiftId).HasColumnName("shift_id");

            entity.HasOne(d => d.GradeOffering).WithMany(p => p.GradeOfferingShifts)
                .HasForeignKey(d => d.GradeOfferingId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("grade_offering_shifts_grade_offering_id_fkey");

            entity.HasOne(d => d.Shift).WithMany(p => p.GradeOfferingShifts)
                .HasForeignKey(d => d.ShiftId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("grade_offering_shifts_shift_id_fkey");
        });

        modelBuilder.Entity<GradeOfferingShiftSection>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("grade_offering_shift_sections_pkey");

            entity.ToTable("grade_offering_shift_sections");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.GradeOfferingShiftId).HasColumnName("grade_offering_shift_id");
            entity.Property(e => e.Section)
                .HasMaxLength(1)
                .HasColumnName("section");
            entity.Property(e => e.SectionNumber).HasColumnName("section_number");

            entity.HasOne(d => d.GradeOfferingShift).WithMany(p => p.GradeOfferingShiftSections)
                .HasForeignKey(d => d.GradeOfferingShiftId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("grade_offering_shift_sections_grade_offering_shift_id_fkey");
        });

        modelBuilder.Entity<Institution>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("institution_pkey");

            entity.ToTable("institution");

            entity.HasIndex(e => e.Name, "institution_name_key").IsUnique();

            entity.HasIndex(e => e.Ruc, "institution_ruc_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(70)
                .HasColumnName("name");
            entity.Property(e => e.Ruc)
                .HasMaxLength(11)
                .IsFixedLength()
                .HasColumnName("ruc");
            entity.Property(e => e.RucStateId).HasColumnName("ruc_state_id");

            entity.HasOne(d => d.RucState).WithMany(p => p.Institutions)
                .HasForeignKey(d => d.RucStateId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("institution_ruc_state_id_fkey");
        });

        modelBuilder.Entity<InstitutionLevel>(entity =>
        {
            entity
                .HasNoKey()
                .ToTable("institution_levels");

            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.InstitutionId).HasColumnName("institution_id");
            entity.Property(e => e.IsActive).HasColumnName("is_active");
            entity.Property(e => e.LevelId).HasColumnName("level_id");
            entity.Property(e => e.StartDate).HasColumnName("start_date");

            entity.HasOne(d => d.Institution).WithMany()
                .HasForeignKey(d => d.InstitutionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("institution_levels_institution_id_fkey");

            entity.HasOne(d => d.Level).WithMany()
                .HasForeignKey(d => d.LevelId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("institution_levels_level_id_fkey");
        });

        modelBuilder.Entity<Language>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("languages_pkey");

            entity.ToTable("languages");

            entity.HasIndex(e => e.Name, "idx_languages_name").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(59)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Level>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("academic_levels_pkey");

            entity.ToTable("levels");

            entity.Property(e => e.Id)
                .HasDefaultValueSql("nextval('academic_levels_id_seq'::regclass)")
                .HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(50)
                .HasColumnName("name");
            entity.Property(e => e.OrderIndex).HasColumnName("order_index");
        });

        modelBuilder.Entity<LevelOfEducation>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("level_of_education_pkey");

            entity.ToTable("level_of_education");

            entity.HasIndex(e => e.Name, "level_of_education_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(40)
                .HasColumnName("name");
        });

        modelBuilder.Entity<PaymentMethod>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("payment_methods_pkey");

            entity.ToTable("payment_methods");

            entity.HasIndex(e => e.Name, "payment_methods_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(50)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Permission>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("permissions_pkey");

            entity.ToTable("permissions");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(30)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Person>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("person_pkey");

            entity.ToTable("person");

            entity.HasIndex(e => new { e.DocumentTypeId, e.IdDocumentNumber }, "unique_document_type_number").IsUnique();

            entity.HasIndex(e => e.IdDocumentNumber, "unique_id_document_number").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Address).HasColumnName("address");
            entity.Property(e => e.AddressUbigeoId).HasColumnName("address_ubigeo_id");
            entity.Property(e => e.BirthDate).HasColumnName("birth_date");
            entity.Property(e => e.CellPhone)
                .HasMaxLength(20)
                .HasColumnName("cell_phone");
            entity.Property(e => e.CivilStateId).HasColumnName("civil_state_id");
            entity.Property(e => e.DocumentTypeId).HasColumnName("document_type_id");
            entity.Property(e => e.Email)
                .HasMaxLength(100)
                .HasColumnName("email");
            entity.Property(e => e.GenderId).HasColumnName("gender_id");
            entity.Property(e => e.IdDocumentNumber)
                .HasMaxLength(20)
                .HasColumnName("id_document_number");
            entity.Property(e => e.LandlinePhone)
                .HasMaxLength(20)
                .HasColumnName("landline_phone");
            entity.Property(e => e.MaternalLastname)
                .HasMaxLength(40)
                .HasColumnName("maternal_lastname");
            entity.Property(e => e.Names)
                .HasMaxLength(100)
                .HasColumnName("names");
            entity.Property(e => e.PaternalLastname)
                .HasMaxLength(40)
                .HasColumnName("paternal_lastname");
            entity.Property(e => e.ReligionId).HasColumnName("religion_id");

            entity.HasOne(d => d.AddressUbigeo).WithMany(p => p.People)
                .HasForeignKey(d => d.AddressUbigeoId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("person_address_ubigeo_id_fkey");

            entity.HasOne(d => d.CivilState).WithMany(p => p.People)
                .HasForeignKey(d => d.CivilStateId)
                .HasConstraintName("person_civil_state_id_fkey");

            entity.HasOne(d => d.DocumentType).WithMany(p => p.People)
                .HasForeignKey(d => d.DocumentTypeId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("person_document_type_id_fkey");

            entity.HasOne(d => d.Gender).WithMany(p => p.People)
                .HasForeignKey(d => d.GenderId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("person_gender_id_fkey");

            entity.HasOne(d => d.Religion).WithMany(p => p.People)
                .HasForeignKey(d => d.ReligionId)
                .HasConstraintName("person_religion_id_fkey");
        });

        modelBuilder.Entity<Province>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("province_pkey");

            entity.ToTable("province");

            entity.HasIndex(e => e.DepartmentId, "idx_province_department_id");

            entity.HasIndex(e => new { e.Code, e.DepartmentId }, "province_code_department_id_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code)
                .HasMaxLength(2)
                .IsFixedLength()
                .HasColumnName("code");
            entity.Property(e => e.DepartmentId).HasColumnName("department_id");
            entity.Property(e => e.Name)
                .HasMaxLength(100)
                .HasColumnName("name");

            entity.HasOne(d => d.Department).WithMany(p => p.Provinces)
                .HasForeignKey(d => d.DepartmentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("province_department_id_fkey");
        });

        modelBuilder.Entity<Religion>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("religion_pkey");

            entity.ToTable("religion");

            entity.HasIndex(e => e.Name, "religion_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(40)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Role>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("roles_pkey");

            entity.ToTable("roles");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(30)
                .HasColumnName("name");

            entity.HasMany(d => d.Permissions).WithMany(p => p.Roles)
                .UsingEntity<Dictionary<string, object>>(
                    "RolePermission",
                    r => r.HasOne<Permission>().WithMany()
                        .HasForeignKey("PermissionId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("role_permissions_permission_id_fkey"),
                    l => l.HasOne<Role>().WithMany()
                        .HasForeignKey("RoleId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("role_permissions_role_id_fkey"),
                    j =>
                    {
                        j.HasKey("RoleId", "PermissionId").HasName("role_permissions_pkey");
                        j.ToTable("role_permissions");
                        j.IndexerProperty<int>("RoleId").HasColumnName("role_id");
                        j.IndexerProperty<int>("PermissionId").HasColumnName("permission_id");
                    });
        });

        modelBuilder.Entity<RucState>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("ruc_states_pkey");

            entity.ToTable("ruc_states");

            entity.HasIndex(e => e.Name, "ruc_states_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(50)
                .HasColumnName("name");
        });

        modelBuilder.Entity<SchoolFee>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("school_fee_pkey");

            entity.ToTable("school_fee");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.EnrollmentPrice)
                .HasPrecision(5, 2)
                .HasColumnName("enrollment_price");
            entity.Property(e => e.LevelId).HasColumnName("level_id");
            entity.Property(e => e.RegistrationFee)
                .HasPrecision(5, 2)
                .HasColumnName("registration_fee");
            entity.Property(e => e.SchoolFeeConceptId).HasColumnName("school_fee_concept_id");
            entity.Property(e => e.SchoolYearId).HasColumnName("school_year_id");
            entity.Property(e => e.ShiftId).HasColumnName("shift_id");
            entity.Property(e => e.TuitionCost)
                .HasPrecision(5, 2)
                .HasColumnName("tuition_cost");

            entity.HasOne(d => d.Level).WithMany(p => p.SchoolFees)
                .HasForeignKey(d => d.LevelId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("school_fee_level_id_fkey");

            entity.HasOne(d => d.SchoolFeeConcept).WithMany(p => p.SchoolFees)
                .HasForeignKey(d => d.SchoolFeeConceptId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("school_fee_school_fee_concept_id_fkey");

            entity.HasOne(d => d.SchoolYear).WithMany(p => p.SchoolFees)
                .HasForeignKey(d => d.SchoolYearId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("school_fee_school_year_id_fkey");

            entity.HasOne(d => d.Shift).WithMany(p => p.SchoolFees)
                .HasForeignKey(d => d.ShiftId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("school_fee_shift_id_fkey");
        });

        modelBuilder.Entity<SchoolFeeConcept>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("school_fee_concepts_pkey");

            entity.ToTable("school_fee_concepts");

            entity.HasIndex(e => e.Name, "school_fee_concepts_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(40)
                .HasColumnName("name");
        });

        modelBuilder.Entity<SchoolYear>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("school_year_pkey");

            entity.ToTable("school_year");

            entity.HasIndex(e => e.Year, "school_year_year_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.IsActive).HasColumnName("is_active");
            entity.Property(e => e.StartDate).HasColumnName("start_date");
            entity.Property(e => e.Year).HasColumnName("year");
        });

        modelBuilder.Entity<Shift>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("shifts_pkey");

            entity.ToTable("shifts");

            entity.HasIndex(e => e.Name, "shifts_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(6)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Student>(entity =>
        {
            entity.HasKey(e => e.EducationalPersonId).HasName("students_pkey");

            entity.ToTable("students");

            entity.Property(e => e.EducationalPersonId)
                .ValueGeneratedNever()
                .HasColumnName("educational_person_id");
            entity.Property(e => e.BirthUbigeoId).HasColumnName("birth_ubigeo_id");
            entity.Property(e => e.ChildbirthTypeId).HasColumnName("childbirth_type_id");
            entity.Property(e => e.HasDisability).HasColumnName("has_disability");
            entity.Property(e => e.Siblings).HasColumnName("siblings");

            entity.HasOne(d => d.BirthUbigeo).WithMany(p => p.Students)
                .HasForeignKey(d => d.BirthUbigeoId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("students_birth_ubigeo_id_fkey");

            entity.HasOne(d => d.ChildbirthType).WithMany(p => p.Students)
                .HasForeignKey(d => d.ChildbirthTypeId)
                .HasConstraintName("students_childbirth_type_id_fkey");

            entity.HasOne(d => d.EducationalPerson).WithOne(p => p.Student)
                .HasForeignKey<Student>(d => d.EducationalPersonId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("students_educational_person_id_fkey");
        });

        modelBuilder.Entity<StudentHome>(entity =>
        {
            entity.HasKey(e => e.StudentId).HasName("student_homes_pkey");

            entity.ToTable("student_homes");

            entity.Property(e => e.StudentId)
                .ValueGeneratedNever()
                .HasColumnName("student_id");
            entity.Property(e => e.HasElectronicDevices).HasColumnName("has_electronic_devices");
            entity.Property(e => e.HasInternetAccess).HasColumnName("has_internet_access");

            entity.HasOne(d => d.Student).WithOne(p => p.StudentHome)
                .HasForeignKey<StudentHome>(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("student_homes_student_id_fkey");
        });

        modelBuilder.Entity<StudentState>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("student_states_pkey");

            entity.ToTable("student_states");

            entity.HasIndex(e => e.Name, "student_states_name_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.Name)
                .HasMaxLength(40)
                .HasColumnName("name");
        });

        modelBuilder.Entity<StudentStatesByYear>(entity =>
        {
            entity
                .HasNoKey()
                .ToTable("student_states_by_year");

            entity.Property(e => e.SchoolYearId).HasColumnName("school_year_id");
            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.StudentId).HasColumnName("student_id");

            entity.HasOne(d => d.SchoolYear).WithMany()
                .HasForeignKey(d => d.SchoolYearId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("student_states_by_year_school_year_id_fkey");

            entity.HasOne(d => d.Status).WithMany()
                .HasForeignKey(d => d.StatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("student_states_by_year_status_id_fkey");

            entity.HasOne(d => d.Student).WithMany()
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("student_states_by_year_student_id_fkey");
        });

        modelBuilder.Entity<Ubigeo>(entity =>
        {
            entity.HasKey(e => e.DistrictId).HasName("ubigeo_pkey");

            entity.ToTable("ubigeo");

            entity.Property(e => e.DistrictId)
                .ValueGeneratedNever()
                .HasColumnName("district_id");
            entity.Property(e => e.Code)
                .HasMaxLength(6)
                .IsFixedLength()
                .HasColumnName("code");

            entity.HasOne(d => d.District).WithOne(p => p.Ubigeo)
                .HasForeignKey<Ubigeo>(d => d.DistrictId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("ubigeo_district_id_fkey");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("users_pkey");

            entity.ToTable("users");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Email)
                .HasMaxLength(50)
                .HasColumnName("email");
            entity.Property(e => e.HashedPassword)
                .HasMaxLength(255)
                .HasColumnName("hashed_password");
            entity.Property(e => e.IsActive).HasColumnName("is_active");
            entity.Property(e => e.MaternalLastname)
                .HasMaxLength(40)
                .HasColumnName("maternal_lastname");
            entity.Property(e => e.Names)
                .HasMaxLength(50)
                .HasColumnName("names");
            entity.Property(e => e.PaternalLastname)
                .HasMaxLength(40)
                .HasColumnName("paternal_lastname");
            entity.Property(e => e.Phone)
                .HasMaxLength(20)
                .HasColumnName("phone");

            entity.HasMany(d => d.Roles).WithMany(p => p.Users)
                .UsingEntity<Dictionary<string, object>>(
                    "UserRole",
                    r => r.HasOne<Role>().WithMany()
                        .HasForeignKey("RoleId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("user_roles_role_id_fkey"),
                    l => l.HasOne<User>().WithMany()
                        .HasForeignKey("UserId")
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("user_roles_user_id_fkey"),
                    j =>
                    {
                        j.HasKey("UserId", "RoleId").HasName("user_roles_pkey");
                        j.ToTable("user_roles");
                        j.IndexerProperty<int>("UserId").HasColumnName("user_id");
                        j.IndexerProperty<int>("RoleId").HasColumnName("role_id");
                    });
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
