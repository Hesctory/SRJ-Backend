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

        if (filter?.SchoolYearId.HasValue == true)
            query = query.Where(s => s.Enrollments.Any(e => e.SchoolYearId == filter.SchoolYearId.Value));

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
