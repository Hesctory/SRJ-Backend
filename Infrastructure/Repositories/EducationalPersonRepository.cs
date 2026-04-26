using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EducationalPersonRepository : IEducationalPersonRepository
{
    private readonly SRJDbContext _context;

    public EducationalPersonRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsByPersonIdAsync(int personId)
    {
        return await _context.EducationalPeople
            .AnyAsync(ep => ep.PersonId == personId);
    }

    public async Task CreateAsync(int personId, int nativeLanguageId, int? ethnicSelfIdentificationId)
    {
        var ep = new EducationalPerson
        {
            PersonId = personId,
            NativeLanguageId = nativeLanguageId,
            EthnicSelfIdentificationId = ethnicSelfIdentificationId
        };
        _context.EducationalPeople.Add(ep);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(int personId, int nativeLanguageId, int? ethnicSelfIdentificationId)
    {
        var ep = await _context.EducationalPeople.FindAsync(personId);
        if (ep == null) return;
        ep.NativeLanguageId = nativeLanguageId;
        ep.EthnicSelfIdentificationId = ethnicSelfIdentificationId;
        await _context.SaveChangesAsync();
    }

    public async Task AddSecondLanguagesAsync(int personId, List<int> languageIds)
    {
        var set = _context.Set<Dictionary<string, object>>("SecondLanguage");
        foreach (var languageId in languageIds)
        {
            set.Add(new Dictionary<string, object>
            {
                ["EducationalPersonId"] = personId,
                ["SecondLanguageId"] = languageId
            });
        }
        await _context.SaveChangesAsync();
    }

    public async Task DeleteSecondLanguagesByEducationalPersonIdAsync(int educationalPersonId)
    {
        var set = _context.Set<Dictionary<string, object>>("SecondLanguage");
        var rows = await set
            .Where(sl => (int)sl["EducationalPersonId"] == educationalPersonId)
            .ToListAsync();
        if (rows.Count > 0)
        {
            set.RemoveRange(rows);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<bool> TryDeleteAsync(int id)
    {
        var ep = await _context.EducationalPeople.FindAsync(id);
        if (ep == null) return false;
        try
        {
            _context.EducationalPeople.Remove(ep);
            Console.WriteLine("Person Removed");
            await _context.SaveChangesAsync();
            Console.WriteLine("Changes saved");
            return true;
        }
        catch (DbUpdateException)
        {
            _context.Entry(ep).State = EntityState.Unchanged;
            return false;
        }
    }
}
