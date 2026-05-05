using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace SRJBackend.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "audit_log",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    event_type = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    event_data = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("audit_log_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "childbirth_type",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("childbirth_type_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "civil_state",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("civil_state_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "department",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    code = table.Column<string>(type: "character(2)", fixedLength: true, maxLength: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("department_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "disability_degrees",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    degree = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("disability_degrees_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "disability_types",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    type = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("disability_types_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "document_types",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("document_types_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "ethnic_self_identifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ethnic_self_identification = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ethnic_self_identifications_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "familiar_relationship_type",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("familiar_relationship_type_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "genders",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("genders_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "languages",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(59)", maxLength: 59, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("languages_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "level_of_education",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("level_of_education_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "levels",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false, defaultValueSql: "nextval('academic_levels_id_seq'::regclass)"),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    order_index = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("academic_levels_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "payment_methods",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("payment_methods_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "permissions",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("permissions_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "religion",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("religion_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "roles",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("roles_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "ruc_states",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ruc_states_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "school_fee_concepts",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("school_fee_concepts_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "school_year",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    year = table.Column<short>(type: "smallint", nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("school_year_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "shifts",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(6)", maxLength: 6, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("shifts_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "student_states",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    description = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("student_states_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    names = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    paternal_lastname = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    maternal_lastname = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    email = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    hashed_password = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("users_pkey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "province",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    department_id = table.Column<int>(type: "integer", nullable: false),
                    code = table.Column<string>(type: "character(2)", fixedLength: true, maxLength: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("province_pkey", x => x.id);
                    table.ForeignKey(
                        name: "province_department_id_fkey",
                        column: x => x.department_id,
                        principalTable: "department",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "grades",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false, defaultValueSql: "nextval('academic_grades_id_seq'::regclass)"),
                    level_id = table.Column<int>(type: "integer", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    year = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("academic_grades_pkey", x => x.id);
                    table.ForeignKey(
                        name: "academic_grades_level_id_fkey",
                        column: x => x.level_id,
                        principalTable: "levels",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "role_permissions",
                columns: table => new
                {
                    role_id = table.Column<int>(type: "integer", nullable: false),
                    permission_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("role_permissions_pkey", x => new { x.role_id, x.permission_id });
                    table.ForeignKey(
                        name: "role_permissions_permission_id_fkey",
                        column: x => x.permission_id,
                        principalTable: "permissions",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "role_permissions_role_id_fkey",
                        column: x => x.role_id,
                        principalTable: "roles",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "institution",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(70)", maxLength: 70, nullable: false),
                    ruc = table.Column<string>(type: "character(11)", fixedLength: true, maxLength: 11, nullable: false),
                    ruc_state_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("institution_pkey", x => x.id);
                    table.ForeignKey(
                        name: "institution_ruc_state_id_fkey",
                        column: x => x.ruc_state_id,
                        principalTable: "ruc_states",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "school_fee",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    school_year_id = table.Column<int>(type: "integer", nullable: false),
                    level_id = table.Column<int>(type: "integer", nullable: false),
                    shift_id = table.Column<int>(type: "integer", nullable: false),
                    school_fee_concept_id = table.Column<int>(type: "integer", nullable: false),
                    enrollment_price = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: false),
                    tuition_cost = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: false),
                    registration_fee = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("school_fee_pkey", x => x.id);
                    table.ForeignKey(
                        name: "school_fee_level_id_fkey",
                        column: x => x.level_id,
                        principalTable: "levels",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "school_fee_school_fee_concept_id_fkey",
                        column: x => x.school_fee_concept_id,
                        principalTable: "school_fee_concepts",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "school_fee_school_year_id_fkey",
                        column: x => x.school_year_id,
                        principalTable: "school_year",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "school_fee_shift_id_fkey",
                        column: x => x.shift_id,
                        principalTable: "shifts",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "user_roles",
                columns: table => new
                {
                    user_id = table.Column<int>(type: "integer", nullable: false),
                    role_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("user_roles_pkey", x => new { x.user_id, x.role_id });
                    table.ForeignKey(
                        name: "user_roles_role_id_fkey",
                        column: x => x.role_id,
                        principalTable: "roles",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "user_roles_user_id_fkey",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "district",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    province_id = table.Column<int>(type: "integer", nullable: false),
                    code = table.Column<string>(type: "character(2)", fixedLength: true, maxLength: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("district_pkey", x => x.id);
                    table.ForeignKey(
                        name: "district_province_id_fkey",
                        column: x => x.province_id,
                        principalTable: "province",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "grade_offerings",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    grade_id = table.Column<int>(type: "integer", nullable: false),
                    school_year_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("grade_offerings_pkey", x => x.id);
                    table.ForeignKey(
                        name: "grade_offerings_grade_id_fkey",
                        column: x => x.grade_id,
                        principalTable: "grades",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "grade_offerings_school_year_id_fkey",
                        column: x => x.school_year_id,
                        principalTable: "school_year",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "institution_levels",
                columns: table => new
                {
                    level_id = table.Column<int>(type: "integer", nullable: false),
                    institution_id = table.Column<int>(type: "integer", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true)
                },
                constraints: table =>
                {
                    table.ForeignKey(
                        name: "institution_levels_institution_id_fkey",
                        column: x => x.institution_id,
                        principalTable: "institution",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "institution_levels_level_id_fkey",
                        column: x => x.level_id,
                        principalTable: "levels",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "ubigeo",
                columns: table => new
                {
                    district_id = table.Column<int>(type: "integer", nullable: false),
                    code = table.Column<string>(type: "character(6)", fixedLength: true, maxLength: 6, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("ubigeo_pkey", x => x.district_id);
                    table.ForeignKey(
                        name: "ubigeo_district_id_fkey",
                        column: x => x.district_id,
                        principalTable: "district",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "grade_offering_shifts",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    grade_offering_id = table.Column<int>(type: "integer", nullable: false),
                    sections = table.Column<short>(type: "smallint", nullable: true),
                    shift_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("grade_offering_shifts_pkey", x => x.id);
                    table.ForeignKey(
                        name: "grade_offering_shifts_grade_offering_id_fkey",
                        column: x => x.grade_offering_id,
                        principalTable: "grade_offerings",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "grade_offering_shifts_shift_id_fkey",
                        column: x => x.shift_id,
                        principalTable: "shifts",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "person",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    names = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    paternal_lastname = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    maternal_lastname = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    gender_id = table.Column<int>(type: "integer", nullable: false),
                    birth_date = table.Column<DateOnly>(type: "date", nullable: false),
                    document_type_id = table.Column<int>(type: "integer", nullable: false),
                    id_document_number = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    address = table.Column<string>(type: "text", nullable: false),
                    address_ubigeo_id = table.Column<int>(type: "integer", nullable: false),
                    email = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    landline_phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    cell_phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    civil_state_id = table.Column<int>(type: "integer", nullable: true),
                    religion_id = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("person_pkey", x => x.id);
                    table.ForeignKey(
                        name: "person_address_ubigeo_id_fkey",
                        column: x => x.address_ubigeo_id,
                        principalTable: "ubigeo",
                        principalColumn: "district_id");
                    table.ForeignKey(
                        name: "person_civil_state_id_fkey",
                        column: x => x.civil_state_id,
                        principalTable: "civil_state",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "person_document_type_id_fkey",
                        column: x => x.document_type_id,
                        principalTable: "document_types",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "person_gender_id_fkey",
                        column: x => x.gender_id,
                        principalTable: "genders",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "person_religion_id_fkey",
                        column: x => x.religion_id,
                        principalTable: "religion",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "grade_offering_shift_sections",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    grade_offering_shift_id = table.Column<int>(type: "integer", nullable: false),
                    section = table.Column<char>(type: "character(1)", maxLength: 1, nullable: true),
                    section_number = table.Column<short>(type: "smallint", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("grade_offering_shift_sections_pkey", x => x.id);
                    table.ForeignKey(
                        name: "grade_offering_shift_sections_grade_offering_shift_id_fkey",
                        column: x => x.grade_offering_shift_id,
                        principalTable: "grade_offering_shifts",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "educational_person",
                columns: table => new
                {
                    person_id = table.Column<int>(type: "integer", nullable: false),
                    ethnic_self_identification_id = table.Column<int>(type: "integer", nullable: true),
                    native_language_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("educational_person_pkey", x => x.person_id);
                    table.ForeignKey(
                        name: "educational_person_ethnic_self_identification_id_fkey",
                        column: x => x.ethnic_self_identification_id,
                        principalTable: "ethnic_self_identifications",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "educational_person_native_language_id_fkey",
                        column: x => x.native_language_id,
                        principalTable: "languages",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "educational_person_person_id_fkey",
                        column: x => x.person_id,
                        principalTable: "person",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "familiars",
                columns: table => new
                {
                    educational_person_id = table.Column<int>(type: "integer", nullable: false),
                    level_of_education_id = table.Column<int>(type: "integer", nullable: true),
                    occupation = table.Column<string>(type: "character varying(70)", maxLength: 70, nullable: true),
                    workplace = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    lives = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("familiars_pkey", x => x.educational_person_id);
                    table.ForeignKey(
                        name: "familiars_educational_person_id_fkey",
                        column: x => x.educational_person_id,
                        principalTable: "educational_person",
                        principalColumn: "person_id");
                    table.ForeignKey(
                        name: "familiars_level_of_education_id_fkey",
                        column: x => x.level_of_education_id,
                        principalTable: "level_of_education",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "second_languages",
                columns: table => new
                {
                    educational_person_id = table.Column<int>(type: "integer", nullable: false),
                    second_language_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("second_languages_pkey", x => new { x.educational_person_id, x.second_language_id });
                    table.ForeignKey(
                        name: "second_languages_educational_person_id_fkey",
                        column: x => x.educational_person_id,
                        principalTable: "educational_person",
                        principalColumn: "person_id");
                    table.ForeignKey(
                        name: "second_languages_second_language_id_fkey",
                        column: x => x.second_language_id,
                        principalTable: "languages",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "students",
                columns: table => new
                {
                    educational_person_id = table.Column<int>(type: "integer", nullable: false),
                    birth_ubigeo_id = table.Column<int>(type: "integer", nullable: false),
                    has_disability = table.Column<bool>(type: "boolean", nullable: false),
                    siblings = table.Column<short>(type: "smallint", nullable: true),
                    childbirth_type_id = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("students_pkey", x => x.educational_person_id);
                    table.ForeignKey(
                        name: "students_birth_ubigeo_id_fkey",
                        column: x => x.birth_ubigeo_id,
                        principalTable: "ubigeo",
                        principalColumn: "district_id");
                    table.ForeignKey(
                        name: "students_childbirth_type_id_fkey",
                        column: x => x.childbirth_type_id,
                        principalTable: "childbirth_type",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "students_educational_person_id_fkey",
                        column: x => x.educational_person_id,
                        principalTable: "educational_person",
                        principalColumn: "person_id");
                });

            migrationBuilder.CreateTable(
                name: "disabilities",
                columns: table => new
                {
                    student_id = table.Column<int>(type: "integer", nullable: false),
                    has_disability_certificate = table.Column<bool>(type: "boolean", nullable: false),
                    disability_certificate_number = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    disability_type_id = table.Column<int>(type: "integer", nullable: true),
                    disability_degree_id = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("disabilities_pkey", x => x.student_id);
                    table.ForeignKey(
                        name: "disabilities_disability_degree_id_fkey",
                        column: x => x.disability_degree_id,
                        principalTable: "disability_degrees",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "disabilities_disability_type_id_fkey",
                        column: x => x.disability_type_id,
                        principalTable: "disability_types",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "disabilities_student_id_fkey",
                        column: x => x.student_id,
                        principalTable: "students",
                        principalColumn: "educational_person_id");
                });

            migrationBuilder.CreateTable(
                name: "enrollment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    code = table.Column<string>(type: "character(6)", fixedLength: true, maxLength: 6, nullable: false),
                    code_number = table.Column<int>(type: "integer", nullable: false),
                    grade_offering_shift_section_id = table.Column<int>(type: "integer", nullable: false),
                    student_id = table.Column<int>(type: "integer", nullable: true),
                    school_fee_concept_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("enrollment_pkey", x => x.id);
                    table.ForeignKey(
                        name: "enrollment_grade_offering_shift_section_id_fkey",
                        column: x => x.grade_offering_shift_section_id,
                        principalTable: "grade_offering_shift_sections",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "enrollment_school_fee_concept_id_fkey",
                        column: x => x.school_fee_concept_id,
                        principalTable: "school_fee_concepts",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "enrollment_student_id_fkey",
                        column: x => x.student_id,
                        principalTable: "students",
                        principalColumn: "educational_person_id");
                });

            migrationBuilder.CreateTable(
                name: "familiar_student_relationship",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    familiar_id = table.Column<int>(type: "integer", nullable: false),
                    student_id = table.Column<int>(type: "integer", nullable: false),
                    lives_together = table.Column<bool>(type: "boolean", nullable: false),
                    familiar_relationship_type_id = table.Column<int>(type: "integer", nullable: false),
                    isguardian = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("familiar_student_relationship_pkey", x => x.id);
                    table.ForeignKey(
                        name: "familiar_student_relationship_familiar_id_fkey",
                        column: x => x.familiar_id,
                        principalTable: "familiars",
                        principalColumn: "educational_person_id");
                    table.ForeignKey(
                        name: "familiar_student_relationship_familiar_relationship_type_i_fkey",
                        column: x => x.familiar_relationship_type_id,
                        principalTable: "familiar_relationship_type",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "familiar_student_relationship_student_id_fkey",
                        column: x => x.student_id,
                        principalTable: "students",
                        principalColumn: "educational_person_id");
                });

            migrationBuilder.CreateTable(
                name: "student_homes",
                columns: table => new
                {
                    student_id = table.Column<int>(type: "integer", nullable: false),
                    has_electronic_devices = table.Column<bool>(type: "boolean", nullable: false),
                    has_internet_access = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("student_homes_pkey", x => x.student_id);
                    table.ForeignKey(
                        name: "student_homes_student_id_fkey",
                        column: x => x.student_id,
                        principalTable: "students",
                        principalColumn: "educational_person_id");
                });

            migrationBuilder.CreateTable(
                name: "student_states_by_year",
                columns: table => new
                {
                    student_id = table.Column<int>(type: "integer", nullable: false),
                    status_id = table.Column<int>(type: "integer", nullable: false),
                    school_year_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.ForeignKey(
                        name: "student_states_by_year_school_year_id_fkey",
                        column: x => x.school_year_id,
                        principalTable: "school_year",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "student_states_by_year_status_id_fkey",
                        column: x => x.status_id,
                        principalTable: "student_states",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "student_states_by_year_student_id_fkey",
                        column: x => x.student_id,
                        principalTable: "students",
                        principalColumn: "educational_person_id");
                });

            migrationBuilder.CreateIndex(
                name: "civil_state_name_key",
                table: "civil_state",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "department_code_key",
                table: "department",
                column: "code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "department_name_key",
                table: "department",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_disabilities_disability_degree_id",
                table: "disabilities",
                column: "disability_degree_id");

            migrationBuilder.CreateIndex(
                name: "IX_disabilities_disability_type_id",
                table: "disabilities",
                column: "disability_type_id");

            migrationBuilder.CreateIndex(
                name: "district_code_province_id_key",
                table: "district",
                columns: new[] { "code", "province_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_district_province_id",
                table: "district",
                column: "province_id");

            migrationBuilder.CreateIndex(
                name: "document_types_name_key",
                table: "document_types",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_educational_person_ethnic_self_identification_id",
                table: "educational_person",
                column: "ethnic_self_identification_id");

            migrationBuilder.CreateIndex(
                name: "IX_educational_person_native_language_id",
                table: "educational_person",
                column: "native_language_id");

            migrationBuilder.CreateIndex(
                name: "IX_enrollment_grade_offering_shift_section_id",
                table: "enrollment",
                column: "grade_offering_shift_section_id");

            migrationBuilder.CreateIndex(
                name: "IX_enrollment_school_fee_concept_id",
                table: "enrollment",
                column: "school_fee_concept_id");

            migrationBuilder.CreateIndex(
                name: "IX_enrollment_student_id",
                table: "enrollment",
                column: "student_id");

            migrationBuilder.CreateIndex(
                name: "IX_familiar_student_relationship_familiar_id",
                table: "familiar_student_relationship",
                column: "familiar_id");

            migrationBuilder.CreateIndex(
                name: "IX_familiar_student_relationship_familiar_relationship_type_id",
                table: "familiar_student_relationship",
                column: "familiar_relationship_type_id");

            migrationBuilder.CreateIndex(
                name: "IX_familiar_student_relationship_student_id",
                table: "familiar_student_relationship",
                column: "student_id");

            migrationBuilder.CreateIndex(
                name: "IX_familiars_level_of_education_id",
                table: "familiars",
                column: "level_of_education_id");

            migrationBuilder.CreateIndex(
                name: "genders_name_key",
                table: "genders",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_grade_offering_shift_sections_grade_offering_shift_id",
                table: "grade_offering_shift_sections",
                column: "grade_offering_shift_id");

            migrationBuilder.CreateIndex(
                name: "IX_grade_offering_shifts_grade_offering_id",
                table: "grade_offering_shifts",
                column: "grade_offering_id");

            migrationBuilder.CreateIndex(
                name: "IX_grade_offering_shifts_shift_id",
                table: "grade_offering_shifts",
                column: "shift_id");

            migrationBuilder.CreateIndex(
                name: "IX_grade_offerings_grade_id",
                table: "grade_offerings",
                column: "grade_id");

            migrationBuilder.CreateIndex(
                name: "IX_grade_offerings_school_year_id",
                table: "grade_offerings",
                column: "school_year_id");

            migrationBuilder.CreateIndex(
                name: "IX_grades_level_id",
                table: "grades",
                column: "level_id");

            migrationBuilder.CreateIndex(
                name: "institution_name_key",
                table: "institution",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "institution_ruc_key",
                table: "institution",
                column: "ruc",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_institution_ruc_state_id",
                table: "institution",
                column: "ruc_state_id");

            migrationBuilder.CreateIndex(
                name: "IX_institution_levels_institution_id",
                table: "institution_levels",
                column: "institution_id");

            migrationBuilder.CreateIndex(
                name: "IX_institution_levels_level_id",
                table: "institution_levels",
                column: "level_id");

            migrationBuilder.CreateIndex(
                name: "idx_languages_name",
                table: "languages",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "level_of_education_name_key",
                table: "level_of_education",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "payment_methods_name_key",
                table: "payment_methods",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_person_address_ubigeo_id",
                table: "person",
                column: "address_ubigeo_id");

            migrationBuilder.CreateIndex(
                name: "IX_person_civil_state_id",
                table: "person",
                column: "civil_state_id");

            migrationBuilder.CreateIndex(
                name: "IX_person_gender_id",
                table: "person",
                column: "gender_id");

            migrationBuilder.CreateIndex(
                name: "IX_person_religion_id",
                table: "person",
                column: "religion_id");

            migrationBuilder.CreateIndex(
                name: "unique_document_type_number",
                table: "person",
                columns: new[] { "document_type_id", "id_document_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "unique_id_document_number",
                table: "person",
                column: "id_document_number",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_province_department_id",
                table: "province",
                column: "department_id");

            migrationBuilder.CreateIndex(
                name: "province_code_department_id_key",
                table: "province",
                columns: new[] { "code", "department_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "religion_name_key",
                table: "religion",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_role_permissions_permission_id",
                table: "role_permissions",
                column: "permission_id");

            migrationBuilder.CreateIndex(
                name: "ruc_states_name_key",
                table: "ruc_states",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_school_fee_level_id",
                table: "school_fee",
                column: "level_id");

            migrationBuilder.CreateIndex(
                name: "IX_school_fee_school_fee_concept_id",
                table: "school_fee",
                column: "school_fee_concept_id");

            migrationBuilder.CreateIndex(
                name: "IX_school_fee_school_year_id",
                table: "school_fee",
                column: "school_year_id");

            migrationBuilder.CreateIndex(
                name: "IX_school_fee_shift_id",
                table: "school_fee",
                column: "shift_id");

            migrationBuilder.CreateIndex(
                name: "school_fee_concepts_name_key",
                table: "school_fee_concepts",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "school_year_year_key",
                table: "school_year",
                column: "year",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_second_languages_second_language_id",
                table: "second_languages",
                column: "second_language_id");

            migrationBuilder.CreateIndex(
                name: "shifts_name_key",
                table: "shifts",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "student_states_name_key",
                table: "student_states",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_student_states_by_year_school_year_id",
                table: "student_states_by_year",
                column: "school_year_id");

            migrationBuilder.CreateIndex(
                name: "IX_student_states_by_year_status_id",
                table: "student_states_by_year",
                column: "status_id");

            migrationBuilder.CreateIndex(
                name: "IX_student_states_by_year_student_id",
                table: "student_states_by_year",
                column: "student_id");

            migrationBuilder.CreateIndex(
                name: "IX_students_birth_ubigeo_id",
                table: "students",
                column: "birth_ubigeo_id");

            migrationBuilder.CreateIndex(
                name: "IX_students_childbirth_type_id",
                table: "students",
                column: "childbirth_type_id");

            migrationBuilder.CreateIndex(
                name: "IX_user_roles_role_id",
                table: "user_roles",
                column: "role_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "audit_log");

            migrationBuilder.DropTable(
                name: "disabilities");

            migrationBuilder.DropTable(
                name: "enrollment");

            migrationBuilder.DropTable(
                name: "familiar_student_relationship");

            migrationBuilder.DropTable(
                name: "institution_levels");

            migrationBuilder.DropTable(
                name: "payment_methods");

            migrationBuilder.DropTable(
                name: "role_permissions");

            migrationBuilder.DropTable(
                name: "school_fee");

            migrationBuilder.DropTable(
                name: "second_languages");

            migrationBuilder.DropTable(
                name: "student_homes");

            migrationBuilder.DropTable(
                name: "student_states_by_year");

            migrationBuilder.DropTable(
                name: "user_roles");

            migrationBuilder.DropTable(
                name: "disability_degrees");

            migrationBuilder.DropTable(
                name: "disability_types");

            migrationBuilder.DropTable(
                name: "grade_offering_shift_sections");

            migrationBuilder.DropTable(
                name: "familiars");

            migrationBuilder.DropTable(
                name: "familiar_relationship_type");

            migrationBuilder.DropTable(
                name: "institution");

            migrationBuilder.DropTable(
                name: "permissions");

            migrationBuilder.DropTable(
                name: "school_fee_concepts");

            migrationBuilder.DropTable(
                name: "student_states");

            migrationBuilder.DropTable(
                name: "students");

            migrationBuilder.DropTable(
                name: "roles");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.DropTable(
                name: "grade_offering_shifts");

            migrationBuilder.DropTable(
                name: "level_of_education");

            migrationBuilder.DropTable(
                name: "ruc_states");

            migrationBuilder.DropTable(
                name: "childbirth_type");

            migrationBuilder.DropTable(
                name: "educational_person");

            migrationBuilder.DropTable(
                name: "grade_offerings");

            migrationBuilder.DropTable(
                name: "shifts");

            migrationBuilder.DropTable(
                name: "ethnic_self_identifications");

            migrationBuilder.DropTable(
                name: "languages");

            migrationBuilder.DropTable(
                name: "person");

            migrationBuilder.DropTable(
                name: "grades");

            migrationBuilder.DropTable(
                name: "school_year");

            migrationBuilder.DropTable(
                name: "ubigeo");

            migrationBuilder.DropTable(
                name: "civil_state");

            migrationBuilder.DropTable(
                name: "document_types");

            migrationBuilder.DropTable(
                name: "genders");

            migrationBuilder.DropTable(
                name: "religion");

            migrationBuilder.DropTable(
                name: "levels");

            migrationBuilder.DropTable(
                name: "district");

            migrationBuilder.DropTable(
                name: "province");

            migrationBuilder.DropTable(
                name: "department");
        }
    }
}
