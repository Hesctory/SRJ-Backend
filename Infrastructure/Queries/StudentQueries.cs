using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
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
                EF.Functions.ILike(s.EducationalPerson.Person.Names, $"%{filter.FullName}%") ||
                EF.Functions.ILike(s.EducationalPerson.Person.PaternalLastname, $"%{filter.FullName}%") ||
                EF.Functions.ILike(s.EducationalPerson.Person.MaternalLastname, $"%{filter.FullName}%"));

        if (!string.IsNullOrWhiteSpace(filter?.Dni))
            query = query.Where(s => s.EducationalPerson.Person.IdDocumentNumber.Contains(filter.Dni));

        var total = await query.CountAsync();
        var items = await query
            .Skip(skip).Take(take)
            .Select(s => new StudentListDTO
            {
                id = s.EducationalPersonId,
                FullName = (s.EducationalPerson.Person.Names + " " +
                            s.EducationalPerson.Person.PaternalLastname + " " +
                            s.EducationalPerson.Person.MaternalLastname).Trim(),
                Dni = s.EducationalPerson.Person.IdDocumentNumber
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
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.AddressUbigeo)
                        .ThenInclude(u => u.District)
                            .ThenInclude(d => d.Province)
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.SecondLanguages)
            .Include(s => s.FamiliarStudentRelationships)
                .ThenInclude(fsr => fsr.Familiar)
                    .ThenInclude(f => f.EducationalPerson)
                        .ThenInclude(ep => ep.Person)
                            .ThenInclude(p => p.AddressUbigeo)
                                .ThenInclude(u => u.District)
                                    .ThenInclude(d => d.Province)
            .Include(s => s.FamiliarStudentRelationships)
                .ThenInclude(fsr => fsr.Familiar)
                    .ThenInclude(f => f.EducationalPerson)
                        .ThenInclude(ep => ep.SecondLanguages)
            .FirstOrDefaultAsync(s => s.EducationalPersonId == id);

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

        return await query
            .Select(e => new StudentReportItemDTO
            {
                Id = e.Id,
                EnrollmentCode = e.Code,
                DocumentNumber = e.Student!.EducationalPerson.Person.IdDocumentNumber,
                FullName = (e.Student!.EducationalPerson.Person.Names + " " +
                            e.Student!.EducationalPerson.Person.PaternalLastname + " " +
                            e.Student!.EducationalPerson.Person.MaternalLastname).Trim(),
                GradeYear = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Year,
                Year = e.SchoolYear.Year,
                Level = e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.Grade.Level.Name,
                Shift = e.GradeOfferingShiftSection.GradeOfferingShift.Shift.Name,
                Section = e.GradeOfferingShiftSection.Section
            })
            .ToListAsync();
    }

    private static StudentDetailDTO MapToDTO(Student s)
    {
        var person = s.EducationalPerson.Person;
        var ep = s.EducationalPerson;

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
            Id = s.EducationalPersonId,
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
            NativeLanguageId = ep.NativeLanguageId,
            EthnicSelfIdentificationId = ep.EthnicSelfIdentificationId,
            SecondLanguageIds = ep.SecondLanguages.Count > 0
                ? ep.SecondLanguages.Select(l => l.Id).ToList()
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
        var ep = familiar.EducationalPerson;
        var person = ep.Person;

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
            NativeLanguageId = ep.NativeLanguageId,
            EthnicSelfIdentificationId = ep.EthnicSelfIdentificationId,
            SecondLanguageIds = ep.SecondLanguages.Count > 0
                ? ep.SecondLanguages.Select(l => l.Id).ToList()
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
