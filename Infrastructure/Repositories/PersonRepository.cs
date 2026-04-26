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
            Names = domainPerson.Names,
            PaternalLastname = domainPerson.PaternalLastname,
            MaternalLastname = domainPerson.MaternalLastname,
            GenderId = domainPerson.GenderId,
            BirthDate = domainPerson.BirthDate,
            DocumentTypeId = domainPerson.DocumentTypeId,
            IdDocumentNumber = domainPerson.IdDocumentNumber,
            Address = domainPerson.Address,
            AddressUbigeoId = domainPerson.AddressUbigeoId,
            ReligionId = domainPerson.ReligionId,
            CivilStateId = domainPerson.CivilStateId,
            Email = domainPerson.Email,
            LandlinePhone = domainPerson.LandlinePhone,
            CellPhone = domainPerson.CellPhone
        };
        _context.People.Add(person);
        await _context.SaveChangesAsync();
        return person.Id;
    }

    public async Task UpdateAsync(int personId, DPerson domainPerson)
    {
        var person = await _context.People.FindAsync(personId);
        if (person == null) return;
        person.Names = domainPerson.Names;
        person.PaternalLastname = domainPerson.PaternalLastname;
        person.MaternalLastname = domainPerson.MaternalLastname;
        person.GenderId = domainPerson.GenderId;
        person.BirthDate = domainPerson.BirthDate;
        person.DocumentTypeId = domainPerson.DocumentTypeId;
        person.IdDocumentNumber = domainPerson.IdDocumentNumber;
        person.Address = domainPerson.Address;
        person.AddressUbigeoId = domainPerson.AddressUbigeoId;
        person.ReligionId = domainPerson.ReligionId;
        person.CivilStateId = domainPerson.CivilStateId;
        person.Email = domainPerson.Email;
        person.LandlinePhone = domainPerson.LandlinePhone;
        person.CellPhone = domainPerson.CellPhone;
        await _context.SaveChangesAsync();
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
