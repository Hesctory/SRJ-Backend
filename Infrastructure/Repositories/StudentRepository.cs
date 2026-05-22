using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class StudentRepository : IStudentRepository
{
    private readonly SRJDbContext _context;

    public StudentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<DStudent> Items, int Total)> GetPagedAsync(int skip, int take)
    {
        var query = _context.Students
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.Gender)
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.DocumentType);

        var total = await query.CountAsync();
        var students = await query.Skip(skip).Take(take).ToListAsync();

        return (students.Select(MapToDomain).ToList(), total);
    }

    public async Task CreateAsync(DStudent student, int personId)
    {
        var s = new Student
        {
            EducationalPersonId = personId,
            BirthUbigeoId = student.BirthLocation.DistrictId,
            HasDisability = student.Profile.HasDisability,
            Siblings = student.Profile.Siblings,
            ChildbirthTypeId = student.Profile.ChildbirthTypeId
        };
        _context.Students.Add(s);
        await _context.SaveChangesAsync();
    }

    public async Task CreateHomeAsync(DStudent student, int studentId)
    {
        var home = new StudentHome
        {
            StudentId = studentId,
            HasElectronicDevices = student.Profile.HasElectronicDevices,
            HasInternetAccess = student.Profile.HasInternetAccess
        };
        _context.StudentHomes.Add(home);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(DStudent student)
    {
        var s = await _context.Students.FindAsync(student.Id);
        if (s == null) return;
        s.BirthUbigeoId = student.BirthLocation.DistrictId;
        s.HasDisability = student.Profile.HasDisability;
        s.Siblings = student.Profile.Siblings;
        s.ChildbirthTypeId = student.Profile.ChildbirthTypeId;
        await _context.SaveChangesAsync();
    }

    public async Task UpdateHomeAsync(DStudent student)
    {
        var home = await _context.StudentHomes.FirstOrDefaultAsync(h => h.StudentId == student.Id);
        if (home == null) return;
        home.HasElectronicDevices = student.Profile.HasElectronicDevices;
        home.HasInternetAccess = student.Profile.HasInternetAccess;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> ExistsAsync(int id) =>
        await _context.Students.AnyAsync(s => s.EducationalPersonId == id);

    public async Task<bool> TryDeleteAsync(int id)
    {
        var student = await _context.Students.FindAsync(id);
        if (student == null) return false;
        try
        {
            _context.Students.Remove(student);
            await _context.SaveChangesAsync();
            return true;
        }
        catch (Microsoft.EntityFrameworkCore.DbUpdateException)
        {
            _context.Entry(student).State = Microsoft.EntityFrameworkCore.EntityState.Unchanged;
            return false;
        }
    }

    public async Task<bool> IsArchivedAsync(int id)
    {
        var student = await _context.Students.FindAsync(id);
        return student?.IsArchived ?? false;
    }

    public async Task<bool> ArchiveAsync(int id)
    {
        var student = await _context.Students.FindAsync(id);
        if (student == null) return false;
        student.IsArchived = true;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> UnarchiveAsync(int id)
    {
        var student = await _context.Students.FindAsync(id);
        if (student == null) return false;
        student.IsArchived = false;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ExistsByEducationalPersonIdAsync(int educationalPersonId)
    {
        return await _context.Students
            .AnyAsync(s => s.EducationalPersonId == educationalPersonId);
    }

    public async Task<DStudent?> GetByIdAsync(int id)
    {
        var student = await _context.Students
            .Include(s => s.StudentHome)
            .Include(s => s.BirthUbigeo)
                .ThenInclude(u => u.District)
                    .ThenInclude(d => d.Province)
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.Gender)
            .Include(s => s.EducationalPerson)
                .ThenInclude(ep => ep.Person)
                    .ThenInclude(p => p.DocumentType)
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

        return student == null ? null : MapToDomain(student);
    }

    private static DStudent MapToDomain(Student s)
    {
        var person = s.EducationalPerson.Person;
        var ep = s.EducationalPerson;

        var birthLocation = s.BirthUbigeo != null
            ? new DLocation(
                DepartmentId: s.BirthUbigeo.District.Province.DepartmentId,
                ProvinceId: s.BirthUbigeo.District.ProvinceId,
                DistrictId: s.BirthUbigeo.DistrictId)
            : new DLocation(0, 0, s.BirthUbigeoId);

        var addressLocation = person.AddressUbigeo != null
            ? new DLocation(
                DepartmentId: person.AddressUbigeo.District.Province.DepartmentId,
                ProvinceId: person.AddressUbigeo.District.ProvinceId,
                DistrictId: person.AddressUbigeo.DistrictId)
            : new DLocation(0, 0, person.AddressUbigeoId);

        var secondLanguageIds = ep.SecondLanguages.Count > 0
            ? ep.SecondLanguages.Select(l => l.Id).ToList()
            : null;

        var demographics = new EducationalDemographics(ep.NativeLanguageId, ep.EthnicSelfIdentificationId, secondLanguageIds);
        var profile = new StudentProfile(
            s.StudentHome?.HasElectronicDevices ?? false,
            s.StudentHome?.HasInternetAccess ?? false,
            s.HasDisability,
            s.Siblings,
            s.ChildbirthTypeId);

        var familiars = s.FamiliarStudentRelationships
            .Select(fsr => MapFamiliar(fsr))
            .ToList();

        return DStudent.Reconstitute(
            id: s.EducationalPersonId,
            name: new PersonalName(person.Names, person.PaternalLastname, person.MaternalLastname),
            genderId: person.GenderId,
            birthDate: person.BirthDate,
            document: new IdentityDocument(person.DocumentTypeId, person.IdDocumentNumber),
            address: person.Address,
            addressUbigeoId: person.AddressUbigeoId,
            religionId: person.ReligionId,
            civilStateId: person.CivilStateId,
            contact: new ContactInfo(person.Email, person.LandlinePhone, person.CellPhone),
            demographics: demographics,
            profile: profile,
            birthLocation: birthLocation,
            addressLocation: addressLocation,
            familiars: familiars
        );
    }

    private static DFamiliar MapFamiliar(FamiliarStudentRelationship fsr)
    {
        var familiar = fsr.Familiar;
        var ep = familiar.EducationalPerson;
        var person = ep.Person;

        DLocation? addressLocation = null;
        if (person.AddressUbigeo != null)
        {
            addressLocation = new DLocation(
                DepartmentId: person.AddressUbigeo.District.Province.DepartmentId,
                ProvinceId: person.AddressUbigeo.District.ProvinceId,
                DistrictId: person.AddressUbigeo.DistrictId);
        }

        var secondLanguageIds = ep.SecondLanguages.Count > 0
            ? ep.SecondLanguages.Select(l => l.Id).ToList()
            : null;

        var demographics = new EducationalDemographics(ep.NativeLanguageId, ep.EthnicSelfIdentificationId, secondLanguageIds);

        return DFamiliar.Reconstitute(
            id: person.Id,
            name: new PersonalName(person.Names, person.PaternalLastname, person.MaternalLastname),
            genderId: person.GenderId,
            birthDate: person.BirthDate,
            document: new IdentityDocument(person.DocumentTypeId, person.IdDocumentNumber),
            address: person.Address,
            addressUbigeoId: person.AddressUbigeoId,
            religionId: person.ReligionId,
            civilStateId: person.CivilStateId,
            contact: new ContactInfo(person.Email, person.LandlinePhone, person.CellPhone),
            demographics: demographics,
            levelOfEducationId: familiar.LevelOfEducationId,
            occupation: familiar.Occupation,
            workCenter: familiar.Workplace,
            addressLocation: addressLocation,
            lives: familiar.Lives,
            livesWithStudent: fsr.LivesTogether,
            relationshipId: fsr.FamiliarRelationshipTypeId,
            isGuardian: fsr.Isguardian
        );
    }
}
