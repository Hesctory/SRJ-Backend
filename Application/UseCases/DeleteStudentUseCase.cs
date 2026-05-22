using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class DeleteStudentUseCase
{
    private readonly IStudentRepository _studentRepository;
    private readonly IStudentHomeRepository _studentHomeRepository;
    private readonly IFamiliarStudentRelationshipRepository _familiarStudentRelationshipRepository;
    private readonly IFamiliarRepository _familiarRepository;
    private readonly IEducationalPersonRepository _educationalPersonRepository;
    private readonly IPersonRepository _personRepository;

    public DeleteStudentUseCase(
        IStudentRepository studentRepository,
        IStudentHomeRepository studentHomeRepository,
        IFamiliarStudentRelationshipRepository familiarStudentRelationshipRepository,
        IFamiliarRepository familiarRepository,
        IEducationalPersonRepository educationalPersonRepository,
        IPersonRepository personRepository)
    {
        _studentRepository = studentRepository;
        _studentHomeRepository = studentHomeRepository;
        _familiarStudentRelationshipRepository = familiarStudentRelationshipRepository;
        _familiarRepository = familiarRepository;
        _educationalPersonRepository = educationalPersonRepository;
        _personRepository = personRepository;
    }

    public async Task<bool> ExecuteAsync(int id)
    {
        if (!await _studentRepository.ExistsAsync(id)) return false;

        var familiarIds = await _familiarStudentRelationshipRepository.GetFamiliarIdsByStudentIdAsync(id);

        if (familiarIds.Count > 0)
            await _familiarStudentRelationshipRepository.DeleteByStudentIdAsync(id);

        foreach (var familiarId in familiarIds)
        {
            var familiarDeleted = await _familiarRepository.TryDeleteAsync(familiarId);
            if (!familiarDeleted) continue;

            await _educationalPersonRepository.DeleteSecondLanguagesByEducationalPersonIdAsync(familiarId);
            var epDeleted = await _educationalPersonRepository.TryDeleteAsync(familiarId);
            if (!epDeleted) continue;

            await _personRepository.TryDeleteAsync(familiarId);
        }

        if (await _studentHomeRepository.ExistsAsync(id))
            await _studentHomeRepository.DeleteAsync(id);

        var studentDeleted = await _studentRepository.TryDeleteAsync(id);
        if (!studentDeleted)
            return false;

        await _educationalPersonRepository.DeleteSecondLanguagesByEducationalPersonIdAsync(id);
        var studentEpDeleted = await _educationalPersonRepository.TryDeleteAsync(id);
        if (!studentEpDeleted)
            return true;

        await _personRepository.TryDeleteAsync(id);

        return true;
    }
}
