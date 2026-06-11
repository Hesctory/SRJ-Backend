using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Person
{
    public int Id { get; set; }

    public string Names { get; set; } = null!;

    public string PaternalLastname { get; set; } = null!;

    public string MaternalLastname { get; set; } = null!;

    public int GenderId { get; set; }

    public DateOnly BirthDate { get; set; }

    public int DocumentTypeId { get; set; }

    public string IdDocumentNumber { get; set; } = null!;

    public string Address { get; set; } = null!;

    public int AddressUbigeoId { get; set; }

    public string? Email { get; set; }

    public string? LandlinePhone { get; set; }

    public string? CellPhone { get; set; }

    public int? CivilStateId { get; set; }

    public int? ReligionId { get; set; }

    public int? EthnicSelfIdentificationId { get; set; }

    public int? NativeLanguageId { get; set; }

    public virtual Ubigeo AddressUbigeo { get; set; } = null!;

    public virtual CivilState? CivilState { get; set; }

    public virtual DocumentType DocumentType { get; set; } = null!;

    public virtual EthnicSelfIdentification? EthnicSelfIdentification { get; set; }

    public virtual Familiar? Familiar { get; set; }

    public virtual Gender Gender { get; set; } = null!;

    public virtual ICollection<LunchAssignment> LunchAssignments { get; set; } = new List<LunchAssignment>();

    public virtual Language? NativeLanguage { get; set; }

    public virtual Religion? Religion { get; set; }

    public virtual StaffMember? StaffMember { get; set; }

    public virtual Student? Student { get; set; }

    public virtual ICollection<Language> SecondLanguages { get; set; } = new List<Language>();
}
