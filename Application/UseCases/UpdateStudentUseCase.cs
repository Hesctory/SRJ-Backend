using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class UpdateStudentUseCase
{
    private readonly IPersonRepository _personRepository;
    private readonly IEducationalPersonRepository _educationalPersonRepository;
    private readonly IStudentRepository _studentRepository;
    private readonly IFamiliarRepository _familiarRepository;
    private readonly IFamiliarStudentRelationshipRepository _familiarStudentRelationshipRepository;

    public UpdateStudentUseCase(
        IPersonRepository personRepository,
        IEducationalPersonRepository educationalPersonRepository,
        IStudentRepository studentRepository,
        IFamiliarRepository familiarRepository,
        IFamiliarStudentRelationshipRepository familiarStudentRelationshipRepository)
    {
        _personRepository = personRepository;
        _educationalPersonRepository = educationalPersonRepository;
        _studentRepository = studentRepository;
        _familiarRepository = familiarRepository;
        _familiarStudentRelationshipRepository = familiarStudentRelationshipRepository;
    }

    public async Task ExecuteAsync(int id, UpdateStudentDTO dto)
    {
        if (!await _studentRepository.ExistsAsync(id))
            throw new KeyNotFoundException("Student not found.");

        var student = StudentMapper.FromDTO(dto, id);

        await _personRepository.UpdateAsync(id, student);
        await _educationalPersonRepository.UpdateAsync(id, student.Demographics.NativeLanguageId, student.Demographics.EthnicSelfIdentificationId);

        await _educationalPersonRepository.DeleteSecondLanguagesByEducationalPersonIdAsync(id);
        if (student.Demographics.SecondLanguageIds != null && student.Demographics.SecondLanguageIds.Count > 0)
            await _educationalPersonRepository.AddSecondLanguagesAsync(id, student.Demographics.SecondLanguageIds);

        await _studentRepository.UpdateAsync(student);
        await _studentRepository.UpdateHomeAsync(student);

        await _familiarStudentRelationshipRepository.DeleteByStudentIdAsync(id);
        foreach (var familiar in student.Familiars)
        {
            var familiarPersonId = await ResolveFamiliarAsync(familiar);
            await _familiarRepository.CreateRelationshipAsync(familiar, familiarPersonId, id);
        }
    }

    private async Task<int> ResolveFamiliarAsync(DFamiliar familiar)
    {
        var existingPersonId = await _personRepository.FindByDocumentAsync(familiar.Document.DocumentTypeId, familiar.Document.IdDocumentNumber);
        int personId;
        if (existingPersonId == null)
        {
            personId = await _personRepository.CreateAsync(familiar);
            await _educationalPersonRepository.CreateAsync(personId, familiar.Demographics.NativeLanguageId, familiar.Demographics.EthnicSelfIdentificationId);
            if (familiar.Demographics.SecondLanguageIds?.Count > 0)
                await _educationalPersonRepository.AddSecondLanguagesAsync(personId, familiar.Demographics.SecondLanguageIds);
            await _familiarRepository.CreateAsync(familiar, personId);
        }
        else
        {
            personId = existingPersonId.Value;
            await _personRepository.UpdateAsync(personId, familiar);
            await _educationalPersonRepository.UpdateAsync(personId, familiar.Demographics.NativeLanguageId, familiar.Demographics.EthnicSelfIdentificationId);
            await _educationalPersonRepository.DeleteSecondLanguagesByEducationalPersonIdAsync(personId);
            if (familiar.Demographics.SecondLanguageIds?.Count > 0)
                await _educationalPersonRepository.AddSecondLanguagesAsync(personId, familiar.Demographics.SecondLanguageIds);
            if (!await _familiarRepository.ExistsByEducationalPersonIdAsync(personId))
                await _familiarRepository.CreateAsync(familiar, personId);
            else
                await _familiarRepository.UpdateAsync(familiar, personId);
        }
        return personId;
    }
}
