using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class PersonRepository : IPersonRepository
{
    private readonly SRJDbContext _context;

    public PersonRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<int?> FindByDocumentAsync(int documentTypeId, string documentNumber)
    {
        return await _context.People
            .Where(p => p.DocumentTypeId == documentTypeId && p.IdDocumentNumber == documentNumber)
            .Select(p => (int?)p.Id)
            .FirstOrDefaultAsync();
    }

    public async Task<int> CreateAsync(DPerson domainPerson)
    {
        var person = new Person
        {
            Names = domainPerson.Name.Names,
            PaternalLastname = domainPerson.Name.PaternalLastname,
            MaternalLastname = domainPerson.Name.MaternalLastname,
            GenderId = domainPerson.GenderId,
            BirthDate = domainPerson.BirthDate,
            DocumentTypeId = domainPerson.Document.DocumentTypeId,
            IdDocumentNumber = domainPerson.Document.IdDocumentNumber,
            Address = domainPerson.Address,
            AddressUbigeoId = domainPerson.AddressUbigeoId,
            ReligionId = domainPerson.ReligionId,
            CivilStateId = domainPerson.CivilStateId,
            Email = domainPerson.Contact.Email,
            LandlinePhone = domainPerson.Contact.LandlinePhone,
            CellPhone = domainPerson.Contact.CellPhone
        };
        _context.People.Add(person);
        await _context.SaveChangesAsync();
        return person.Id;
    }

    public async Task UpdateAsync(int personId, DPerson domainPerson)
    {
        var person = await _context.People.FindAsync(personId);
        if (person == null) return;
        person.Names = domainPerson.Name.Names;
        person.PaternalLastname = domainPerson.Name.PaternalLastname;
        person.MaternalLastname = domainPerson.Name.MaternalLastname;
        person.GenderId = domainPerson.GenderId;
        person.BirthDate = domainPerson.BirthDate;
        person.DocumentTypeId = domainPerson.Document.DocumentTypeId;
        person.IdDocumentNumber = domainPerson.Document.IdDocumentNumber;
        person.Address = domainPerson.Address;
        person.AddressUbigeoId = domainPerson.AddressUbigeoId;
        person.ReligionId = domainPerson.ReligionId;
        person.CivilStateId = domainPerson.CivilStateId;
        person.Email = domainPerson.Contact.Email;
        person.LandlinePhone = domainPerson.Contact.LandlinePhone;
        person.CellPhone = domainPerson.Contact.CellPhone;
        await _context.SaveChangesAsync();
    }

    public async Task UpdateDemographicsAsync(int personId, int nativeLanguageId, int? ethnicSelfIdentificationId)
    {
        var person = await _context.People.FindAsync(personId);
        if (person == null) return;
        person.NativeLanguageId = nativeLanguageId;
        person.EthnicSelfIdentificationId = ethnicSelfIdentificationId;
        await _context.SaveChangesAsync();
    }

    public async Task AddSecondLanguagesAsync(int personId, List<int> languageIds)
    {
        var set = _context.Set<Dictionary<string, object>>("SecondLanguage");
        foreach (var languageId in languageIds)
        {
            set.Add(new Dictionary<string, object>
            {
                ["PersonId"] = personId,
                ["SecondLanguageId"] = languageId
            });
        }
        await _context.SaveChangesAsync();
    }

    public async Task DeleteSecondLanguagesAsync(int personId)
    {
        var set = _context.Set<Dictionary<string, object>>("SecondLanguage");
        var rows = await set
            .Where(sl => (int)sl["PersonId"] == personId)
            .ToListAsync();
        if (rows.Count > 0)
        {
            set.RemoveRange(rows);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<bool> TryDeleteAsync(int id)
    {
        var person = await _context.People.FindAsync(id);
        if (person == null) return false;
        try
        {
            _context.People.Remove(person);
            await _context.SaveChangesAsync();
            return true;
        }
        catch (DbUpdateException)
        {
            _context.Entry(person).State = EntityState.Unchanged;
            return false;
        }
    }
}
