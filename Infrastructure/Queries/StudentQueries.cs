using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class StudentQueries : IStudentQueries
{
    private readonly SRJDbContext _context;

    public StudentQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<StudentListDTO> Items, int Total)> GetPagedAsync(int skip, int take, StudentFilter? filter = null)
    {
        var query = _context.Students.AsQueryable();

        if (filter?.SchoolYearId.HasValue == true || filter?.LevelId.HasValue == true ||
            filter?.GradeId.HasValue == true || filter?.ShiftId.HasValue == true || filter?.SectionId.HasValue == true)
            query = query.Where(s => s.Enrollments.Any(e =>
                (!filter!.SchoolYearId.HasValue || e.SchoolYearId == filter.SchoolYearId.Value) &&
                (!filter.LevelId.HasValue || e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.LevelId == filter.LevelId.Value) &&
                (!filter.GradeId.HasValue || e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.GradeId == filter.GradeId.Value) &&
                (!filter.ShiftId.HasValue || e.GradeOfferingShiftSection.GradeOfferingShift.ShiftId == filter.ShiftId.Value) &&
                (!filter.SectionId.HasValue || e.GradeOfferingShiftSectionId == filter.SectionId.Value)));

        if (!string.IsNullOrWhiteSpace(filter?.FullName))
            query = query.Where(s =>
                EF.Functions.ILike(s.Person.Names, $"%{filter.FullName}%") ||
                EF.Functions.ILike(s.Person.PaternalLastname, $"%{filter.FullName}%") ||
                EF.Functions.ILike(s.Person.MaternalLastname, $"%{filter.FullName}%"));

        if (!string.IsNullOrWhiteSpace(filter?.Dni))
            query = query.Where(s => s.Person.IdDocumentNumber.Contains(filter.Dni));

        var total = await query.CountAsync();
        var items = await query
            .Skip(skip).Take(take)
            .Select(s => new StudentListDTO
            {
                id = s.PersonId,
                FullName = (s.Person.Names + " " +
                            s.Person.PaternalLastname + " " +
                            s.Person.MaternalLastname).Trim(),
                Dni = s.Person.IdDocumentNumber
            })
            .ToListAsync();
        return (items, total);
    }

    public async Task<StudentDetailDTO?> GetByIdAsync(int id)
    {
        var s = await _context.Students
            .Include(s => s.StudentHome)
            .Include(s => s.BirthUbigeo)
                .ThenInclude(u => u.District)
                    .ThenInclude(d => d.Province)
            .Include(s => s.Person)
                .ThenInclude(p => p.AddressUbigeo)
                    .ThenInclude(u => u.District)
                        .ThenInclude(d => d.Province)
            .Include(s => s.Person)
                .ThenInclude(p => p.SecondLanguages)
            .Include(s => s.FamiliarStudentRelationships)
                .ThenInclude(fsr => fsr.Familiar)
                    .ThenInclude(f => f.Person)
                        .ThenInclude(p => p.AddressUbigeo)
                            .ThenInclude(u => u.District)
                                .ThenInclude(d => d.Province)
            .Include(s => s.FamiliarStudentRelationships)
                .ThenInclude(fsr => fsr.Familiar)
                    .ThenInclude(f => f.Person)
                        .ThenInclude(p => p.SecondLanguages)
            .FirstOrDefaultAsync(s => s.PersonId == id);

        return s == null ? null : MapToDTO(s);
    }

    public async Task<List<StudentReportItemDTO>> GetReportAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId)
    {
        var query = _context.Enrollments
            .AsNoTracking()
            .Where(e => e.StudentId != null)
            .AsQueryable();

        if (schoolYearId.HasValue)
            query = query.Where(e => e.SchoolYearId == schoolYearId.Value);
        if (levelId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.LevelId == levelId.Value);
        if (gradeId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.GradeId == gradeId.Value);
        if (shiftId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.ShiftId == shiftId.Value);
        if (sectionId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSectionId == sectionId.Value);

        var items = await query
            .Select(e => new StudentReportItemDTO
            {
                Id = e.Id,
                EnrollmentCode = e.Code,
                DocumentNumber = e.Student!.Person.IdDocumentNumber,
                FullName = (e.Student!.Person.Names + " " +
                            e.Student!.Person.PaternalLastname + " " +
                            e.Student!.Person.MaternalLastname).Trim(),
                GradeYear = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Year,
                Year = e.SchoolYear.Year,
                Level = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Level.Name,
                Shift = e.GradeOfferingShiftSection.GradeOfferingShift.Shift.Name,
                Section = e.GradeOfferingShiftSection.Section
            })
            .ToListAsync();

        // Canonical ordering: fullName ascending (the frontend no longer sorts).
        return items
            .OrderBy(i => i.FullName, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    public async Task<List<StudentBirthdayDTO>> GetBirthdaysAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId)
    {
        var query = _context.Enrollments.AsNoTracking().AsQueryable();

        if (schoolYearId.HasValue)
            query = query.Where(e => e.SchoolYearId == schoolYearId.Value);
        if (levelId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.LevelId == levelId.Value);
        if (gradeId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.GradeId == gradeId.Value);
        if (shiftId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.ShiftId == shiftId.Value);
        if (sectionId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSectionId == sectionId.Value);

        var rows = await query
            .Select(e => new
            {
                e.StudentId,
                DocumentNumber = e.Student!.Person.IdDocumentNumber,
                e.Student!.Person.PaternalLastname,
                e.Student!.Person.MaternalLastname,
                e.Student!.Person.Names,
                Level = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Level.Name,
                GradeYear = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Year,
                Shift = e.GradeOfferingShiftSection.GradeOfferingShift.Shift.Name,
                Section = e.GradeOfferingShiftSection.Section,
                e.Student!.Person.BirthDate
            })
            .ToListAsync();

        // Sort by day-of-year (month, then day) ignoring birth year so it reads as a
        // calendar; ties broken by fullName. This used to happen client-side.
        return rows
            .OrderBy(r => r.BirthDate.Month)
            .ThenBy(r => r.BirthDate.Day)
            .ThenBy(r => $"{r.PaternalLastname} {r.MaternalLastname}, {r.Names}".Trim(),
                    StringComparer.CurrentCultureIgnoreCase)
            .Select(r => new StudentBirthdayDTO
            {
                Id = r.StudentId,
                DocumentNumber = r.DocumentNumber,
                FullName = $"{r.PaternalLastname} {r.MaternalLastname}, {r.Names}".Trim(),
                Level = r.Level,
                GradeYear = r.GradeYear.ToString(),
                Section = r.Section?.ToString(),
                Shift = r.Shift,
                BirthDate = r.BirthDate.ToString("yyyy-MM-dd")
            })
            .ToList();
    }

    public async Task<List<WithdrawnStudentDTO>> GetWithdrawnAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId)
    {
        var query = _context.Enrollments
            .AsNoTracking()
            .Where(e => e.State.Name == EnrollmentStateNames.Withdrawn)
            .AsQueryable();

        if (schoolYearId.HasValue)
            query = query.Where(e => e.SchoolYearId == schoolYearId.Value);
        if (levelId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.LevelId == levelId.Value);
        if (gradeId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.GradeId == gradeId.Value);
        if (shiftId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.ShiftId == shiftId.Value);
        if (sectionId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSectionId == sectionId.Value);

        var rows = await query
            .Select(e => new
            {
                e.Id,
                e.Code,
                e.Student!.Person.PaternalLastname,
                e.Student!.Person.MaternalLastname,
                e.Student!.Person.Names,
                Level = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Level.Name,
                GradeYear = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Year,
                Shift = e.GradeOfferingShiftSection.GradeOfferingShift.Shift.Name,
                Section = e.GradeOfferingShiftSection.Section,
                e.EnrollmentDate,
                // Latest transition INTO the current (Withdrawn) state, straight from the
                // history table. Null only when no withdrawal was ever recorded for it.
                WithdrawalDate = _context.EnrollmentStateHistories
                    .Where(h => h.EnrollmentId == e.Id && h.ToStateId == e.StateId)
                    .Max(h => (DateTime?)h.ChangedAt)
            })
            .ToListAsync();

        // Canonical ordering: fullName ascending (the frontend no longer sorts).
        return rows
            .Select(r => new WithdrawnStudentDTO
            {
                Id = r.Id,
                EnrollmentCode = r.Code,
                FullName = $"{r.PaternalLastname} {r.MaternalLastname}, {r.Names}".Trim(),
                Level = r.Level,
                GradeYear = r.GradeYear.ToString(),
                Section = r.Section?.ToString(),
                Shift = r.Shift,
                EnrollmentDate = r.EnrollmentDate.ToString("yyyy-MM-dd"),
                WithdrawalDate = r.WithdrawalDate.HasValue
                    ? DateOnly.FromDateTime(r.WithdrawalDate.Value).ToString("yyyy-MM-dd")
                    : null
            })
            .OrderBy(d => d.FullName, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    public async Task<List<RegistrationCardDTO>> GetRegistrationCardAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId,
        List<int>? studentIds)
    {
        var query = _context.Enrollments.AsNoTracking().AsQueryable();

        if (schoolYearId.HasValue)
            query = query.Where(e => e.SchoolYearId == schoolYearId.Value);
        if (levelId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.LevelId == levelId.Value);
        if (gradeId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.GradeId == gradeId.Value);
        if (shiftId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSection.GradeOfferingShift.ShiftId == shiftId.Value);
        if (sectionId.HasValue)
            query = query.Where(e => e.GradeOfferingShiftSectionId == sectionId.Value);
        if (studentIds != null && studentIds.Count > 0)
            query = query.Where(e => studentIds.Contains(e.StudentId));

        var cards = await query.Select(e => new RegistrationCardDTO
        {
            id = e.StudentId,
            enrollmentCode = e.Code,
            enrollmentDate = e.EnrollmentDate.ToString(),
            schoolYear = e.SchoolYear.Year.ToString(),
            level = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Level.Name,
            grade = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Name,
            section = e.GradeOfferingShiftSection.Section != null
                ? e.GradeOfferingShiftSection.Section.Value.ToString()
                : null,
            shift = e.GradeOfferingShiftSection.GradeOfferingShift.Shift.Name,
            paternalLastName = e.Student.Person.PaternalLastname,
            maternalLastName = e.Student.Person.MaternalLastname,
            firstName = e.Student.Person.Names,
            birthDate = e.Student.Person.BirthDate.ToString(),
            birthPlace = e.Student.BirthUbigeo.District.Name,
            birthCountry = "Perú",
            gender = e.Student.Person.Gender.Name,
            religion = e.Student.Person.Religion != null ? e.Student.Person.Religion.Name : null,
            dni = e.Student.Person.IdDocumentNumber,
            siblings = (int?)e.Student.Siblings,
            siblingPosition = (int?)e.Student.BirthOrder,
            disability = e.Student.HasDisability
                ? (e.Student.Disability != null && e.Student.Disability.DisabilityType != null
                    ? e.Student.Disability.DisabilityType.Type
                    : "Sí")
                : "Ninguna",
            previousSchool = e.PreviousSchool,
            address = e.Student.Person.Address,
            district = e.Student.Person.AddressUbigeo.District.Name,
            mother = e.Student.FamiliarStudentRelationships
                .Where(fsr => fsr.FamiliarRelationshipType.Name == "MADRE")
                .Select(fsr => new RegistrationCardParentDTO
                {
                    paternalLastName = fsr.Familiar.Person.PaternalLastname,
                    maternalLastName = fsr.Familiar.Person.MaternalLastname,
                    firstName = fsr.Familiar.Person.Names,
                    dni = fsr.Familiar.Person.IdDocumentNumber,
                    phone = fsr.Familiar.Person.CellPhone != null
                        ? fsr.Familiar.Person.CellPhone
                        : fsr.Familiar.Person.LandlinePhone,
                    email = fsr.Familiar.Person.Email,
                    educationLevel = fsr.Familiar.LevelOfEducation != null ? fsr.Familiar.LevelOfEducation.Name : null,
                    occupation = fsr.Familiar.Occupation,
                    maritalStatus = fsr.Familiar.Person.CivilState != null ? fsr.Familiar.Person.CivilState.Name : null
                })
                .FirstOrDefault(),
            father = e.Student.FamiliarStudentRelationships
                .Where(fsr => fsr.FamiliarRelationshipType.Name == "PADRE")
                .Select(fsr => new RegistrationCardParentDTO
                {
                    paternalLastName = fsr.Familiar.Person.PaternalLastname,
                    maternalLastName = fsr.Familiar.Person.MaternalLastname,
                    firstName = fsr.Familiar.Person.Names,
                    dni = fsr.Familiar.Person.IdDocumentNumber,
                    phone = fsr.Familiar.Person.CellPhone != null
                        ? fsr.Familiar.Person.CellPhone
                        : fsr.Familiar.Person.LandlinePhone,
                    email = fsr.Familiar.Person.Email,
                    educationLevel = fsr.Familiar.LevelOfEducation != null ? fsr.Familiar.LevelOfEducation.Name : null,
                    occupation = fsr.Familiar.Occupation,
                    maritalStatus = fsr.Familiar.Person.CivilState != null ? fsr.Familiar.Person.CivilState.Name : null
                })
                .FirstOrDefault(),
            guardian = e.Student.FamiliarStudentRelationships
                .Where(fsr => fsr.Isguardian)
                .Select(fsr => new RegistrationCardGuardianDTO
                {
                    relationship = fsr.FamiliarRelationshipType.Name,
                    paternalLastName = fsr.Familiar.Person.PaternalLastname,
                    maternalLastName = fsr.Familiar.Person.MaternalLastname,
                    firstName = fsr.Familiar.Person.Names,
                    dni = fsr.Familiar.Person.IdDocumentNumber,
                    phone = fsr.Familiar.Person.CellPhone != null
                        ? fsr.Familiar.Person.CellPhone
                        : fsr.Familiar.Person.LandlinePhone,
                    email = fsr.Familiar.Person.Email
                })
                .FirstOrDefault(),
            fees = e.SchoolFeeConcept.SchoolFees
                .Where(sf => sf.SchoolYearId == e.SchoolYearId
                    && sf.ShiftId == e.GradeOfferingShiftSection.GradeOfferingShift.ShiftId
                    && sf.LevelId == e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.LevelId)
                .Select(sf => new RegistrationCardFeesDTO
                {
                    registrationFee = sf.RegistrationFee,
                    enrollmentFee = sf.EnrollmentPrice,
                    tuition = sf.TuitionCost
                })
                .FirstOrDefault() ?? new RegistrationCardFeesDTO()
        })
        .ToListAsync();

        // Order by fullName for a deterministic page sequence (contract unspecified).
        return cards
            .OrderBy(c => $"{c.paternalLastName} {c.maternalLastName} {c.firstName}".Trim(),
                     StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    public async Task<ReportContextDTO> GetReportContextAsync(
        int? schoolYearId, int? levelId, int? gradeId, int? shiftId, int? sectionId)
    {
        var ctx = new ReportContextDTO();

        if (schoolYearId.HasValue)
            ctx.SchoolYear = (await _context.SchoolYears.AsNoTracking()
                .Where(x => x.Id == schoolYearId.Value)
                .Select(x => (short?)x.Year)
                .FirstOrDefaultAsync())?.ToString();

        if (levelId.HasValue)
            ctx.Level = await _context.Levels.AsNoTracking()
                .Where(x => x.Id == levelId.Value)
                .Select(x => x.Name)
                .FirstOrDefaultAsync();

        if (gradeId.HasValue)
            ctx.Grade = await _context.Grades.AsNoTracking()
                .Where(x => x.Id == gradeId.Value)
                .Select(x => x.Name)
                .FirstOrDefaultAsync();

        if (shiftId.HasValue)
            ctx.Shift = await _context.Shifts.AsNoTracking()
                .Where(x => x.Id == shiftId.Value)
                .Select(x => x.Name)
                .FirstOrDefaultAsync();

        // sectionId is a GradeOfferingShiftSectionId; resolve it to the section letter/number.
        if (sectionId.HasValue)
            ctx.Section = await _context.GradeOfferingShiftSections.AsNoTracking()
                .Where(x => x.Id == sectionId.Value)
                .Select(x => x.Section != null
                    ? x.Section.Value.ToString()
                    : (x.SectionNumber != null ? x.SectionNumber.Value.ToString() : null))
                .FirstOrDefaultAsync();

        return ctx;
    }

    private static StudentDetailDTO MapToDTO(Student s)
    {
        var person = s.Person;

        var birthLocation = s.BirthUbigeo != null
            ? new LocationDTO
            {
                DepartmentId = s.BirthUbigeo.District.Province.DepartmentId,
                ProvinceId = s.BirthUbigeo.District.ProvinceId,
                DistrictId = s.BirthUbigeo.DistrictId
            }
            : new LocationDTO { DistrictId = s.BirthUbigeoId };

        var addressLocation = person.AddressUbigeo != null
            ? new LocationDTO
            {
                DepartmentId = person.AddressUbigeo.District.Province.DepartmentId,
                ProvinceId = person.AddressUbigeo.District.ProvinceId,
                DistrictId = person.AddressUbigeo.DistrictId
            }
            : new LocationDTO { DistrictId = person.AddressUbigeoId };

        return new StudentDetailDTO
        {
            Id = s.PersonId,
            Names = person.Names,
            PaternalLastname = person.PaternalLastname,
            MaternalLastname = person.MaternalLastname,
            FullName = $"{person.Names} {person.PaternalLastname} {person.MaternalLastname}".Trim(),
            GenderId = person.GenderId,
            BirthDate = person.BirthDate,
            DocumentTypeId = person.DocumentTypeId,
            IdDocumentNumber = person.IdDocumentNumber,
            Address = person.Address,
            AddressUbigeoId = person.AddressUbigeoId,
            ReligionId = person.ReligionId,
            CivilStateId = person.CivilStateId,
            Email = person.Email,
            LandlinePhone = person.LandlinePhone,
            CellPhone = person.CellPhone,
            NativeLanguageId = person.NativeLanguageId ?? 0,
            EthnicSelfIdentificationId = person.EthnicSelfIdentificationId,
            SecondLanguageIds = person.SecondLanguages.Count > 0
                ? person.SecondLanguages.Select(l => l.Id).ToList()
                : null,
            HasElectronicDevices = s.StudentHome?.HasElectronicDevices ?? false,
            HasInternetAccess = s.StudentHome?.HasInternetAccess ?? false,
            BirthLocation = birthLocation,
            AddressLocation = addressLocation,
            HasDisability = s.HasDisability,
            Siblings = s.Siblings,
            ChildbirthTypeId = s.ChildbirthTypeId,
            Familiars = s.FamiliarStudentRelationships
                .Select(MapFamiliar)
                .ToList()
        };
    }

    private static FamiliarDetailDTO MapFamiliar(FamiliarStudentRelationship fsr)
    {
        var familiar = fsr.Familiar;
        var person = familiar.Person;

        var addressLocation = person.AddressUbigeo != null
            ? new LocationDTO
            {
                DepartmentId = person.AddressUbigeo.District.Province.DepartmentId,
                ProvinceId = person.AddressUbigeo.District.ProvinceId,
                DistrictId = person.AddressUbigeo.DistrictId
            }
            : null;

        return new FamiliarDetailDTO
        {
            Id = person.Id,
            Names = person.Names,
            PaternalLastname = person.PaternalLastname,
            MaternalLastname = person.MaternalLastname,
            FullName = $"{person.Names} {person.PaternalLastname} {person.MaternalLastname}".Trim(),
            GenderId = person.GenderId,
            BirthDate = person.BirthDate,
            DocumentTypeId = person.DocumentTypeId,
            IdDocumentNumber = person.IdDocumentNumber,
            Address = person.Address,
            AddressUbigeoId = person.AddressUbigeoId,
            ReligionId = person.ReligionId,
            CivilStateId = person.CivilStateId,
            Email = person.Email,
            LandlinePhone = person.LandlinePhone,
            CellPhone = person.CellPhone,
            NativeLanguageId = person.NativeLanguageId ?? 0,
            EthnicSelfIdentificationId = person.EthnicSelfIdentificationId,
            SecondLanguageIds = person.SecondLanguages.Count > 0
                ? person.SecondLanguages.Select(l => l.Id).ToList()
                : null,
            LevelOfEducationId = familiar.LevelOfEducationId,
            Occupation = familiar.Occupation,
            WorkCenter = familiar.Workplace,
            AddressLocation = addressLocation,
            Lives = familiar.Lives,
            LivesWithStudent = fsr.LivesTogether,
            RelationshipId = fsr.FamiliarRelationshipTypeId,
            IsGuardian = fsr.Isguardian
        };
    }
}
